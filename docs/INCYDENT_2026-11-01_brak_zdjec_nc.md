# Incydent 2026-11-01 — brak zdjęć w adminie `nc` po hardeningu

## Objaw
Lista produktów w adminie Django (`nc.sowa.ch`) pokazuje przy każdym produkcie
placeholder **„brak zdj”**. Panel MinIO pod `http://<IP>:9101/browser/nc-media`
zwraca `ERR_CONNECTION_REFUSED`.

## Jak aplikacja wyświetla zdjęcia (repo `pawlo884/nc`)
- Miniatura to zwykły `<img src="…">` z `onerror` podmieniającym obrazek na
  placeholder „brak zdj” (`src/apps/MPD/admin.py`, `src/core/wholesaler_admin/thumbnails.py`).
  Czyli placeholder = **przeglądarka użytkownika nie dostała pliku** z URL-a obrazka.
- URL obrazka = `MINIO_PUBLIC_URL` (fallback: `MINIO_ENDPOINT/nc-media`)
  (`src/apps/matterhorn1/defs_db.py`, `src/core/settings/base.py` → `MEDIA_URL`).
- Wzorzec env (`docs/env.sample.md`):
  `MINIO_ENDPOINT=https://minio-api.sowa.ch`, `MINIO_PUBLIC_URL=https://minio-api.sowa.ch/nc-media`.

## Przyczyna (zmiany z hardeningu 2026-09-12)
1. **`minio-api.sowa.ch` dostał Access List `internal-panels`** (LAN/Tailscale **i** hasło,
   `Deny all` dla reszty) — patrz `docs/TODO_SERWER.md` pkt 1.
   - Z internetu → `403`. Z Tailscale → `401` (basic auth), a przeglądarka nie pokaże
     okna logowania dla obrazka z innej domeny → `onerror` → „brak zdj”.
   - Dla porównania: przed hardeningiem minio-api był publiczny i bucket `nc-media`
     ma anonimowy odczyt — dlatego wcześniej działało.
2. **Porty MinIO 9100 (API) / 9101 (konsola) przypięte do `127.0.0.1`**
   (`scripts/apply-security-localhost.py`) i usunięte z UFW (`ufw_removed_ports`).
   Jeśli w `.env` prod `MINIO_PUBLIC_URL` / `MINIO_ENDPOINT` wskazywał `http://<IP>:9100`,
   to też przestało działać. 9101 (konsola) jest zamknięta **celowo** — konsola ma
   być dostępna tylko jako `https://minio.sowa.ch` (LAN/Tailscale) albo tunelem SSH.
3. **Efekt uboczny do sprawdzenia: upload z Celery.** Jeśli `MINIO_ENDPOINT` to
   `https://minio-api.sowa.ch`, kontener `nc-celery-*` łączy się przez Cloudflare →
   NPM, a NPM widzi adres Cloudflare (nie LAN/Tailscale) → `403`. Nowe zdjęcia z importu
   nie trafią do MinIO, nawet gdy wyświetlanie zostanie naprawione.

## Diagnoza na serwerze (2 minuty)
```bash
# 1. Jakie URL-e ma aplikacja w prod
docker exec nc-web env | grep -E '^(MINIO_|MEDIA_URL|AWS_S3_ENDPOINT)'

# 2. Czy obrazek jest dostępny publicznie (z telefonu na LTE albo):
curl -sI https://minio-api.sowa.ch/nc-media/ | head -1      # 403/401 = potwierdza pkt 1

# 3. Czy MinIO żyje i jak NPM do niego trafia
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i minio
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' $(docker ps -qf name=minio)
docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' nc-web nc-celery-fast

# 4. Czy upload z kontenera przechodzi
docker exec nc-celery-fast python -c "import os,urllib.request as u; \
  print(u.urlopen(os.environ['MINIO_ENDPOINT']+'/minio/health/live').status)"
```

## Naprawa

### A. Wyświetlanie (wymagane) — publiczny, tylko-do-odczytu dostęp do `/nc-media/`
NPM → Proxy Hosts → `minio-api.sowa.ch` → **Advanced** → dopisać:
```nginx
# Publiczny odczyt zdjęć produktów (bucket nc-media). Access List z "Details"
# dotyczy tylko "location /", więc ta lokalizacja jest poza nią.
location /nc-media/ {
    limit_except GET HEAD { deny all; }
    include conf.d/include/proxy.conf;
}
```
Access List `internal-panels` zostaje na reszcie hosta (API S3, listowanie bucketów,
upload, inne buckety). Weryfikacja z zewnątrz (LTE, bez Tailscale):
```bash
curl -sI https://minio-api.sowa.ch/nc-media/<jakis-plik>.jpg | head -1   # 200
curl -sI https://minio-api.sowa.ch/ | head -1                            # 403
curl -s -X PUT https://minio-api.sowa.ch/nc-media/x -o /dev/null -w '%{http_code}\n'  # 403
```
Alternatywa (czystsza, ale wymaga zmiany env i DNS): osobny host `media.sowa.ch` bez
Access List, z tą samą lokalizacją, i `MINIO_PUBLIC_URL=https://media.sowa.ch/nc-media`.

### B. Upload z kontenerów (jeśli pkt 4 diagnozy daje błąd)
Kontenery `nc` są w sieci `nginx_proxy_manager_network`. Jeśli MinIO też tam jest
(pkt 3 diagnozy), w `.env` prod ustawić wewnętrzny endpoint, a publiczny URL zostawić:
```
MINIO_ENDPOINT=http://<nazwa-kontenera-minio>:9000
MINIO_PUBLIC_URL=https://minio-api.sowa.ch/nc-media
```
i przeładować `nc-web` + `nc-celery-*` (`scripts/deploy-prod.sh` albo
`docker compose -f docker-compose/docker-compose.prod.yml up -d`).
Jeśli MinIO nie jest w tej sieci: `docker network connect nginx_proxy_manager_network <minio>`
i dopisać tę sieć w `/home/pawel/stacks/minio/docker-compose.yml`, żeby przeżyła restart.

### C. Konsola MinIO
Nie otwierać 9101 z powrotem. Konsola: `https://minio.sowa.ch` z LAN/Tailscale, albo
`ssh -L 9101:127.0.0.1:9101 pawel@<host>` i `http://localhost:9101`.

## Lekcja
Przy zakładaniu Access List na host sprawdzić, czy nie serwuje on zasobów
ładowanych przez publiczne strony (obrazki, pliki) — `minio-api` to nie tylko panel.
