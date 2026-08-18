#!/bin/bash
set -u
echo "=== container ==="
docker ps --filter name=^prometheus$ --format '{{.Names}} {{.Status}} {{.Ports}}'

echo
echo "=== health ==="
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9090/-/healthy

echo
echo "=== NPM ==="
sudo sqlite3 /srv/nginx-proxy-manager/data/database.sqlite \
  "SELECT id, domain_names, forward_host, forward_port, enabled, certificate_id FROM proxy_host WHERE domain_names LIKE '%prom%' OR forward_host LIKE '%prom%';"

echo
echo "=== DNS ==="
dig +short prometheus.sowa.ch || true
dig +short prom.sowa.ch || true

echo
echo "=== targets ==="
curl -s http://127.0.0.1:9090/api/v1/targets -o /tmp/pt.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/pt.json"))
for t in d["data"]["activeTargets"]:
    print(t["labels"].get("job"), t["health"], t["labels"].get("instance"), (t.get("lastError") or "")[:80])
PY

echo
echo "=== networks ==="
docker inspect prometheus --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
