#!/bin/bash
set -u
echo "=== prom targets postgres ==="
curl -s http://127.0.0.1:9090/api/v1/targets -o /tmp/t.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/t.json"))
for t in d["data"]["activeTargets"]:
    job=t["labels"].get("job","")
    if "postgres" in job or "pg" in job:
        print(job, t["health"], t["labels"].get("instance"), (t.get("lastError") or "")[:150])
print("--- all ---")
for t in d["data"]["activeTargets"]:
    print(t["labels"].get("job"), t["health"], t["labels"].get("instance"))
PY

echo
echo "=== pg_up / metrics sample ==="
curl -s http://127.0.0.1:9188/metrics | grep -E '^pg_up|^pg_stat|^pg_database|^pg_exporter' | head -40

echo
echo "=== prom query pg_up ==="
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=pg_up' -o /tmp/pgup.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/pgup.json"))
print(json.dumps(d, indent=2)[:800])
PY

echo
echo "=== grafana dashboards ==="
curl -s -u admin:admin 'http://127.0.0.1:3000/api/search?query=PostgreSQL' 
echo
curl -s -u admin:admin 'http://127.0.0.1:3000/api/dashboards/uid/000000039' -o /tmp/pgdash.json
python3 - <<'PY'
import json
d=json.load(open("/tmp/pgdash.json"))
dash=d.get("dashboard",{})
print("title", dash.get("title"), "uid", dash.get("uid"))
templ=dash.get("templating",{}).get("list",[])
for v in templ:
    print("var", v.get("name"), "type", v.get("type"), "query", str(v.get("query"))[:80], "current", v.get("current"))
# sample first panel target
for p in dash.get("panels",[])[:3]:
    print("panel", p.get("title"), "ds", p.get("datasource"))
    for t in (p.get("targets") or [])[:1]:
        print("  expr", (t.get("expr") or "")[:120], "ds", t.get("datasource"))
PY

echo
echo "=== exporter container ==="
docker ps -a --filter name=postgres_exporter --format '{{.Names}} {{.Status}} {{.Ports}}'
docker inspect postgres_exporter_nc --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null
docker logs postgres_exporter_nc --tail 20 2>&1
