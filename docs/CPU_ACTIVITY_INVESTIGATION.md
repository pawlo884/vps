# Analiza ruchu CPU (skoki w Netdata)

## Co widać w logach

W oknie czasowym z wykresu (ok. 12:00–12:20 UTC) w `journalctl` widać:

- **wol-auto-wake.service** uruchamia się **co ~10 sekund** (timer `OnUnitActiveSec=10s`).
- Każde uruchomienie: nowy proces bash, sprawdzenie portów TCP (timeout do 2 s na port), ewentualnie `ip route`, zapis do logu.

To daje **6 uruchomień na minutę** i może odpowiadać za okresowe skoki „user” CPU na wykresie.

## Główna przyczyna

**Timer WOL (wol-auto-wake.timer)** ustawiony na **10 s** – bardzo częste uruchomienia skryptu, który:

- sprawdza porty 8090 i 8501 na `192.168.50.63`,
- przy każdej próbie uruchamia `timeout` + bash + połączenia TCP.

Stąd powtarzające się, niewielkie piki CPU co ~10 s, które na wykresie „Total CPU” sumują się w widoczne skoki.

## Co można zrobić

1. **Zwiększyć interwał timera** (np. 30 s lub 60 s) – mniej uruchomień, mniej obciążenia CPU, nadal sensowny czas reakcji na 502.
2. **Zostawić 10 s** – jeśli priorytetem jest jak najszybsze budzenie po 502.

## Inne źródła obciążenia (z listy procesów)

- **netdata** – stałe zbieranie metryk (kilka % CPU).
- **cAdvisor** – metryki kontenerów.
- **PostgreSQL** – połączenia „idle in transaction”.
- **Celery** (kolejka `import`), **Grafana**, **Cursor** (gdy jest sesja) – mogą dawać wyższe piki przy pracy.

## Dalsza analiza (opcjonalnie)

- **sysstat**: `sar -u` dla historycznego CPU (np. `sar -u -f /var/log/sysstat/sarDD`).
- **Netdata** → Applications / Containers – przypisanie CPU do konkretnych procesów/kontenerów.
- Ręcznie: `top -b -n 1` lub `ps aux --sort=-%cpu` w cronie co 5 min z zapisem do pliku, żeby potem powiązać z wykresem.
