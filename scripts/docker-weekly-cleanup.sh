#!/bin/bash
# Cotygodniowe czyszczenie Dockera: build cache i nieużywane obrazy
# Uruchamiane przez systemd timer (np. w niedzielę o 3:00)

set -e
LOG_TAG="docker-weekly-cleanup"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$LOG_TAG] $1"
    logger -t "$LOG_TAG" "$1"
}

log "Start czyszczenia Dockera"

# Build cache – zwalnia najwięcej miejsca, bezpieczne dla działających kontenerów
log "Czyszczenie build cache..."
docker builder prune -af
log "Build cache wyczyszczony."

# Nieużywane obrazy (nie używane przez żaden kontener)
log "Czyszczenie nieużywanych obrazów..."
docker image prune -af
log "Nieużywane obrazy usunięte."

log "Cotygodniowe czyszczenie Dockera zakończone."
