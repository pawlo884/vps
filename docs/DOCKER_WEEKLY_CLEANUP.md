# Cotygodniowe czyszczenie Dockera

Automat co tydzień (w niedzielę o 3:00) uruchamia:
- `docker builder prune -af` – usuwa build cache (~dziesiątki GB)
- `docker image prune -af` – usuwa nieużywane obrazy

Działające kontenery i ich obrazy **nie są** usuwane.

## Instalacja (jednorazowo)

```bash
# Skrypt
sudo cp /opt/vps/scripts/docker-weekly-cleanup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-weekly-cleanup.sh

# Jednostki systemd
sudo cp /opt/vps/scripts/docker-weekly-cleanup.service /etc/systemd/system/
sudo cp /opt/vps/scripts/docker-weekly-cleanup.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable docker-weekly-cleanup.timer
sudo systemctl start docker-weekly-cleanup.timer
```

## Sprawdzenie

```bash
# Czy timer jest włączony i kiedy następne uruchomienie
systemctl list-timers docker-weekly-cleanup.timer

# Ręczne uruchomienie (test)
sudo systemctl start docker-weekly-cleanup.service

# Logi z ostatniego czyszczenia
journalctl -u docker-weekly-cleanup.service -n 30
```

## Wyłączenie

```bash
sudo systemctl stop docker-weekly-cleanup.timer
sudo systemctl disable docker-weekly-cleanup.timer
```
