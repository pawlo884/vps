#!/usr/bin/env python3
"""Fix PostgreSQL Grafana dashboard variables to match Prometheus labels."""
from __future__ import annotations

import base64
import json
import subprocess
import urllib.parse
import urllib.request

GRAFANA = "http://127.0.0.1:3000"
UID = "000000039"
ADMIN_PASS = "admin"


def auth_headers():
    token = base64.b64encode(f"admin:{ADMIN_PASS}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}


def api(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(GRAFANA + path, data=data, method=method, headers=auth_headers())
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode()
        return resp.status, json.loads(raw) if raw else None


def main():
    subprocess.check_call(
        ["docker", "exec", "grafana", "grafana", "cli", "admin", "reset-admin-password", ADMIN_PASS]
    )

    _, wrap = api("GET", f"/api/dashboards/uid/{UID}")
    dash = wrap["dashboard"]
    meta = wrap.get("meta", {})

    for var in dash.get("templating", {}).get("list", []):
        name = var.get("name")
        if name == "instance":
            var["type"] = "query"
            var["datasource"] = {"type": "prometheus", "uid": "prometheus"}
            var["query"] = "label_values(pg_up, instance)"
            var["definition"] = "label_values(pg_up, instance)"
            var["refresh"] = 2
            var["includeAll"] = False
            var["multi"] = False
            var["current"] = {"selected": True, "text": "nc-postgres-1", "value": "nc-postgres-1"}
            var["options"] = []
            print("fixed instance var")
        elif name == "datname":
            var["type"] = "query"
            var["datasource"] = {"type": "prometheus", "uid": "prometheus"}
            var["query"] = (
                'label_values(pg_stat_database_tup_fetched{instance="$instance",'
                'datname!~"template.*|postgres"}, datname)'
            )
            var["definition"] = var["query"]
            var["refresh"] = 2
            var["includeAll"] = True
            var["multi"] = True
            var["allValue"] = ".*"
            var["current"] = {"selected": True, "text": "All", "value": "$__all"}
            print("fixed datname var")
        elif name == "mode":
            var["datasource"] = {"type": "prometheus", "uid": "prometheus"}

    def fix_panels(panels):
        for p in panels or []:
            if "datasource" in p:
                p["datasource"] = {"type": "prometheus", "uid": "prometheus"}
            for t in p.get("targets") or []:
                if "datasource" in t:
                    t["datasource"] = {"type": "prometheus", "uid": "prometheus"}
            fix_panels(p.get("panels"))

    fix_panels(dash.get("panels"))

    payload = {
        "dashboard": dash,
        "folderUid": meta.get("folderUid") or "observability",
        "overwrite": True,
        "message": "fix instance/datname variables for nc-postgres-1",
    }
    code, body = api("POST", "/api/dashboards/db", payload)
    print("save", code, body.get("uid") if isinstance(body, dict) else body, body.get("status") if isinstance(body, dict) else "")

    q = 'sum(pg_stat_database_tup_fetched{instance="nc-postgres-1"})'
    with urllib.request.urlopen(
        "http://127.0.0.1:9090/api/v1/query?" + urllib.parse.urlencode({"query": q}),
        timeout=10,
    ) as resp:
        data = json.load(resp)
    print("prom sample", data["data"]["result"])

    # Persist fixed dashboard JSON for future imports
    out = "/home/pawel/stacks/observability/grafana/dashboard-src/postgresql-nc-postgres-1.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(dash, f, indent=2)
        f.write("\n")
    print("wrote", out)


if __name__ == "__main__":
    main()
