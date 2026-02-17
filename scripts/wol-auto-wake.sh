#!/bin/bash
# Automatyczne budzenie urządzenia gdy NPM wykryje 502 dla aplikacji
# Uruchamiane przez systemd timer co 10 sekund

TARGET_IP="192.168.50.63"
TARGET_MAC="4C:CC:6A:B9:98:6E"  # MAC adres urządzenia 192.168.50.63
PORTS=(8090 8501)  # Porty aplikacji na urządzeniu
LOCK_FILE="/tmp/wol-wake.lock"
LAST_WAKE_FILE="/tmp/wol-last-wake"
LOG_FILE="/var/log/wol-auto-wake.log"

# Funkcja logowania
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" 2>/dev/null
}

# Funkcja sprawdzająca czy urządzenie odpowiada
check_device() {
    local ip=$1
    local port=$2
    timeout 2 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
    return $?
}

# Funkcja wysyłająca WoL
send_wol() {
    local mac=$1
    log "Wysyłam WoL dla MAC: $mac"
    
    # Spróbuj wakeonlan
    if command -v wakeonlan &> /dev/null; then
        if wakeonlan "$mac" 2>/dev/null; then
            log "WoL wysłany przez wakeonlan"
            return 0
        fi
    fi
    
    # Albo etherwake
    if command -v etherwake &> /dev/null; then
        # Znajdź interfejs sieciowy (pierwszy nie-loopback)
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

# Główna logika
main() {
    # Sprawdź lock - unikaj wielokrotnego budzenia
    if [ -f "$LOCK_FILE" ]; then
        if [ -f "$LAST_WAKE_FILE" ]; then
            LAST_WAKE=$(cat "$LAST_WAKE_FILE" 2>/dev/null || echo 0)
            NOW=$(date +%s)
            DIFF=$((NOW - LAST_WAKE))
            
            # Nie budź ponownie jeśli budziłeś w ciągu ostatnich 90 sekund
            if [ $DIFF -lt 90 ]; then
                exit 0
            fi
        fi
    fi
    
    # Sprawdź logi NPM dla błędów 502 związanych z TARGET_IP
    NPM_LOGS=$(docker logs nginx-proxy-manager --since 15s --tail 30 2>/dev/null)
    
    if echo "$NPM_LOGS" | grep -qiE "502|Bad Gateway|Connection refused" && \
       echo "$NPM_LOGS" | grep -q "$TARGET_IP"; then
        
        log "Wykryto 502/Bad Gateway dla $TARGET_IP w logach NPM"
        
        # Sprawdź czy urządzenie rzeczywiście nie odpowiada
        DEVICE_UP=false
        for port in "${PORTS[@]}"; do
            if check_device "$TARGET_IP" "$port"; then
                DEVICE_UP=true
                log "Urządzenie $TARGET_IP:$port odpowiada - nie budzę"
                break
            fi
        done
        
        if [ "$DEVICE_UP" = false ]; then
            log "Urządzenie $TARGET_IP nie odpowiada - budzę..."
            
            # Utwórz lock
            touch "$LOCK_FILE"
            echo "$(date +%s)" > "$LAST_WAKE_FILE"
            
            # Wyślij WoL
            if send_wol "$TARGET_MAC"; then
                log "WoL wysłany. Czekam 30 sekund na obudzenie..."
                sleep 30
                
                # Sprawdź czy urządzenie się obudziło
                for port in "${PORTS[@]}"; do
                    if check_device "$TARGET_IP" "$port"; then
                        log "Urządzenie się obudziło! Odpowiada na porcie $port"
                        rm -f "$LOCK_FILE" 2>/dev/null
                        exit 0
                    fi
                done
                
                log "Urządzenie nadal nie odpowiada po 30 sekundach"
            fi
            
            # Usuń lock po 90 sekundach (w tle)
            (sleep 90 && rm -f "$LOCK_FILE" 2>/dev/null) &
        fi
    fi
}

# Uruchom główną funkcję
main

exit 0
