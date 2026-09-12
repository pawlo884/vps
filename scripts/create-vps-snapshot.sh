#!/usr/bin/env bash

# Pre-deploy snapshot:
# - metadata systemu i Dockera
# - dumpy wszystkich uruchomionych kontenerow postgres
# - archiwum compose/stacks z /opt/vps
#
# Uzycie:
#   ./scripts/create-vps-snapshot.sh
#   SNAPSHOT_BASE_DIR=/inna/sciezka ./scripts/create-vps-snapshot.sh

set -euo pipefail

timestamp="$(date +%Y%m%d_%H%M%S)"
host_name="$(hostname -s 2>/dev/null || hostname)"

default_base_dir="/mnt/data2tb/snapshots"
snapshot_base_dir="${SNAPSHOT_BASE_DIR:-$default_base_dir}"
snapshot_dir="${snapshot_base_dir}/${host_name}_${timestamp}"
meta_dir="${snapshot_dir}/meta"
db_dir="${snapshot_dir}/databases"
archive_dir="${snapshot_dir}/archives"

if ! mkdir -p "$meta_dir" "$db_dir" "$archive_dir" 2>/dev/null; then
  fallback_base_dir="${HOME}/snapshots"
  snapshot_base_dir="$fallback_base_dir"
  snapshot_dir="${snapshot_base_dir}/${host_name}_${timestamp}"
  meta_dir="${snapshot_dir}/meta"
  db_dir="${snapshot_dir}/databases"
  archive_dir="${snapshot_dir}/archives"
  mkdir -p "$meta_dir" "$db_dir" "$archive_dir"
  echo "INFO: Brak uprawnien do /mnt/data2tb/snapshots, uzywam fallback: ${fallback_base_dir}"
fi

echo "[1/6] Zapis metadanych systemu..."
{
  echo "timestamp=${timestamp}"
  echo "host=${host_name}"
  echo "kernel=$(uname -a)"
  echo "cwd=$(pwd)"
} > "${meta_dir}/snapshot.info"

df -h > "${meta_dir}/df-h.txt" || true
free -h > "${meta_dir}/free-h.txt" || true
ss -tulpen > "${meta_dir}/ports.txt" || true
systemctl list-units --type=service --state=running > "${meta_dir}/running-services.txt" || true

echo "[2/6] Zapis stanu Dockera..."
docker ps -a > "${meta_dir}/docker-ps-a.txt"
docker images > "${meta_dir}/docker-images.txt"
docker volume ls > "${meta_dir}/docker-volumes.txt"
docker network ls > "${meta_dir}/docker-networks.txt"
docker compose ls > "${meta_dir}/docker-compose-ls.txt" || true

echo "[3/6] Snapshot konfiguracji projektu /opt/vps..."
tar -czf "${archive_dir}/opt-vps_stacks_and_ansible.tar.gz" \
  -C /opt/vps \
  stacks ansible scripts docs README.md TESTING.md rola.md 2>/dev/null || true

echo "[4/6] Snapshot docker inspect dla kontenerow..."
while IFS= read -r cname; do
  [ -n "$cname" ] || continue
  docker inspect "$cname" > "${meta_dir}/inspect_${cname}.json" || true
done < <(docker ps -a --format '{{.Names}}')

echo "[5/6] Tworzenie dumpow Postgresa (kazdy kontener osobno)..."
postgres_containers="$(
  docker ps --format '{{.Names}} {{.Image}}' \
    | awk '$2 ~ /^postgres(:|$)/ || $2 ~ /^postgis\/postgis(:|$)/ {print $1}'
)"

if [ -z "$postgres_containers" ]; then
  echo "Brak uruchomionych kontenerow postgres - pomijam dumpy." | tee "${db_dir}/README.txt"
else
  dump_errors=0
  while IFS= read -r cname; do
    [ -n "$cname" ] || continue

    pg_user_env="$(docker inspect "$cname" --format '{{range .Config.Env}}{{println .}}{{end}}' \
      | grep '^POSTGRES_USER=' \
      | sed 's/^POSTGRES_USER=//' \
      | head -n 1 || true)"
    pg_user_env="${pg_user_env:-}"

    out_file="${db_dir}/${cname}_all_databases.sql.gz"
    echo "  - ${cname} -> ${out_file}"

    # pg_dumpall wymaga uprawnien superusera kontenera.
    # Dla standardowych kontenerow postgres POSTGRES_USER ma takie uprawnienia.
    dump_ok=0
    for user_try in "$pg_user_env" "postgres" "pawel" "doadmin"; do
      [ -n "$user_try" ] || continue
      if docker exec "$cname" pg_dumpall -U "$user_try" | gzip > "$out_file"; then
        echo "    OK (user=${user_try})"
        dump_ok=1
        break
      fi
    done

    if [ "$dump_ok" -ne 1 ]; then
      echo "  ! BLAD dumpa dla ${cname}" | tee -a "${db_dir}/ERRORS.txt"
      rm -f "$out_file"
      dump_errors=1
    fi
  done <<< "$postgres_containers"

  if [ "$dump_errors" -eq 1 ]; then
    echo "Uwaga: czesc dumpow postgres nie powiodla sie (szczegoly: ${db_dir}/ERRORS.txt)"
  fi
fi

echo "[6/6] Tworzenie manifestu i checksum..."
{
  echo "snapshot_dir=${snapshot_dir}"
  echo "created_at=$(date --iso-8601=seconds)"
  echo "host=${host_name}"
  echo "docker_ps_count=$(docker ps -a --format '{{.Names}}' | wc -l)"
  echo "postgres_containers_count=$(docker ps --format '{{.Image}}' | grep -E '^postgres(:|$)|^postgis/postgis(:|$)' | wc -l || true)"
} > "${snapshot_dir}/MANIFEST.txt"

(
  cd "$snapshot_dir"
  find . -type f -print0 | xargs -0 sha256sum > SHA256SUMS.txt
)

echo
echo "Snapshot gotowy:"
echo "  ${snapshot_dir}"
echo
echo "Weryfikacja checksum:"
echo "  cd \"${snapshot_dir}\" && sha256sum -c SHA256SUMS.txt"
