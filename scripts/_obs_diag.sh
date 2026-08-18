#!/bin/bash
set -u
echo "=== prom targets ==="
curl -s http://127.0.0.1:9090/api/v1/targets > /tmp/prom_targets.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/prom_targets.json"))
for t in d["data"]["activeTargets"]:
    err=(t.get("lastError") or "")[:120]
    print(t["labels"].get("job"), t["health"], t["labels"].get("instance"), err)
PY

echo
echo "=== up ==="
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up' > /tmp/prom_up.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/prom_up.json"))
for r in d["data"]["result"]:
    print(r["metric"].get("job"), r["metric"].get("instance"), r["value"][1])
PY

echo
echo "=== dashboard files ==="
ls -la /home/pawel/stacks/observability/grafana/dashboards/
echo
python3 - <<'PY'
import json,glob,os
for p in sorted(glob.glob("/home/pawel/stacks/observability/grafana/dashboards/*.json")):
    with open(p) as f:
        d=json.load(f)
    print(os.path.basename(p), "title=", d.get("title"), "uid=", d.get("uid"), "id=", d.get("id"),
          "keys=", sorted(d.keys())[:20])
    # look for dashboard uid refs
    s=json.dumps(d)
    if "dashboards:uid" in s or '"type": "dashboard"' in s or '"type":"dashboard"' in s:
        print("  HAS dashboard link refs")
PY

echo
echo "=== npm proxies ==="
docker exec nginx-proxy-manager sqlite3 /data/database.sqlite \
  'SELECT id, domain_names, forward_host, forward_port, enabled, certificate_id FROM proxy_host;'

echo
echo "=== grafana networks ==="
docker inspect grafana --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

echo
echo "=== compose grafana env ==="
grep -A30 'grafana:' /home/pawel/stacks/observability/docker-compose.yml | head -35
