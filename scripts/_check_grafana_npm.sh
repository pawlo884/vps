#!/bin/bash
set -u
echo "=== NPM proxy ==="
sudo sqlite3 /srv/nginx-proxy-manager/data/database.sqlite \
  "SELECT id, domain_names, forward_host, forward_port, forward_scheme, enabled, certificate_id, ssl_forced FROM proxy_host WHERE domain_names LIKE '%grafana%' OR forward_host LIKE '%grafana%';"

echo
echo "=== conf files ==="
grep -l grafana /srv/nginx-proxy-manager/data/nginx/proxy_host/*.conf 2>/dev/null || true
for f in /srv/nginx-proxy-manager/data/nginx/proxy_host/*.conf; do
  if grep -q 'grafana' "$f" 2>/dev/null; then
    echo "--- $f ---"
    grep -E 'server_name|forward|set \$server|set \$port|ssl_certificate|listen' "$f"
  fi
done

echo
echo "=== local Host header http ==="
curl -sI -H 'Host: grafana.sowa.ch' http://127.0.0.1/login | head -15

echo
echo "=== npm -> grafana ==="
docker exec nginx-proxy-manager curl -s -o /dev/null -w '%{http_code}\n' http://grafana:3000/api/health || echo fail

echo
echo "=== public https ==="
curl -sI https://grafana.sowa.ch/login | head -20

echo
echo "=== public http ==="
curl -sI http://grafana.sowa.ch/login | head -15

echo
echo "=== grafana container ==="
docker ps --filter name=^grafana$ --format '{{.Names}} {{.Status}} {{.Ports}}'
