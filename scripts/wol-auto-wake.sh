#!/bin/bash
# Automatyczne budzenie urządzenia gdy NPM zwróci 502 dla aplikacji
# Działa na żądanie: nasłuchuje logów NPM w czasie rzeczywistym (docker logs -f),
# reaguje tylko gdy pojawi się 502/Bad Gateway dla TARGET_IP. Bez pollingu.

TARGET_IP="192.168.50.63"
TARGET_MAC="4C:CC:6A:B9:98:6E"  # MAC urządzenia 192.168.50.63
PORTS=(8090 8501)  # Porty aplikacji na urządzeniu
LOCK_FILE="/tmp/wol-wake.lock"
LAST_WAKE_FILE="/tmp/wol-last-wake"
LOG_FILE="/var/log/wol-auto-wake.log"
NPM_CONTAINER="nginx-proxy-manager"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null
}

check_device() {
    local ip=$1
    local port=$2
    timeout 2 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
    return $?
}

send_wol() {
    local mac=$1
    log "Wysyłam WoL dla MAC: $mac"
    if command -v wakeonlan &> /dev/null; then
        if wakeonlan "$mac" 2>/dev/null; then
            log "WoL wysłany przez wakeonlan"
            return 0
        fi
    fi
    if command -v etherwake &> /dev/null; then
        INTERFACE=$(ip route | grep -oP 'dev \K\w+' | grep -v '^lo$' | head -1)
        if [ -n "$INTERFACE" ]; then
            if etherwake -i "$INTERFACE" "$mac" 2>/dev/null; then
                log "WoL wysłany przez etherwake na interfejsie $INTERFACE"
                return 0
            fi
        fi
    fi
    log "BŁĄD: Nie można wysłać WoL! Zainstaluj: apt-get install wakeonlan"
    return 1
}

# Wywoływane gdy w logu pojawi się 502 dla TARGET_IP
try_wake() {
    # Cooldown: nie budź ponownie w ciągu 90 s
    if [ -f "$LAST_WAKE_FILE" ]; then
        LAST_WAKE=$(cat "$LAST_WAKE_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        if [ $((NOW - LAST_WAKE)) -lt 90 ]; then
            log "Pomijam (cooldown 90s)"
            return 0
        fi
    fi

    # Sprawdź czy urządzenie już odpowiada
    for port in "${PORTS[@]}"; do
        if check_device "$TARGET_IP" "$port"; then
            log "Urządzenie $TARGET_IP:$port odpowiada - nie budzę"
            return 0
        fi
    done

    log "Wykryto 502 dla $TARGET_IP – urządzenie nie odpowiada, budzę..."
    touch "$LOCK_FILE"
    echo "$(date +%s)" > "$LAST_WAKE_FILE"

    if send_wol "$TARGET_MAC"; then
        log "WoL wysłany. Czekam 30 sekund na obudzenie..."
        sleep 30
        for port in "${PORTS[@]}"; do
            if check_device "$TARGET_IP" "$port"; then
                log "Urządzenie się obudziło! Odpowiada na porcie $port"
                rm -f "$LOCK_FILE" 2>/dev/null
                return 0
            fi
        done
        log "Urządzenie nadal nie odpowiada po 30 sekundach"
    fi
    (sleep 90 && rm -f "$LOCK_FILE" 2>/dev/null) &
}

# Główna pętla: strumień logów NPM, reakcja tylko na 502 + TARGET_IP
main() {
    log "Start nasłuchiwania logów NPM (na żądanie, bez pollingu)"
    while true; do
        if ! docker ps -q -f name="$NPM_CONTAINER" | grep -q .; then
            log "Kontener $NPM_CONTAINER niedostępny, czekam 30s..."
            sleep 30
            continue
        fi
        docker logs -f --tail 0 "$NPM_CONTAINER" 2>/dev/null | while read -r line; do
            if echo "$line" | grep -qiE "502|Bad Gateway|Connection refused" && \
               echo "$line" | grep -q "$TARGET_IP"; then
                try_wake
            fi
        done
        log "Strumień logów zakończony, ponowne podłączenie za 5s..."
        sleep 5
    done
}

main
