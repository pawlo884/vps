#!/usr/bin/env python3
"""Fix Grafana dashboard JSON files for reliable file provisioning."""
from __future__ import annotations

import json
from pathlib import Path

DASH_DIR = Path("/home/pawel/stacks/observability/grafana/dashboards")

HOST = {
    "annotations": {"list": []},
    "editable": True,
    "fiscalYearStartMonth": 0,
    "graphTooltip": 0,
    "id": None,
    "links": [],
    "panels": [
        {
            "type": "timeseries",
            "title": "CPU usage %",
            "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
            "id": 1,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": '100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)',
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                }
            ],
        },
        {
            "type": "timeseries",
            "title": "Memory used %",
            "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
            "id": 2,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                }
            ],
        },
        {
            "type": "timeseries",
            "title": "Load average",
            "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
            "id": 3,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {"expr": "node_load1", "refId": "A", "legendFormat": "1m", "datasource": {"type": "prometheus", "uid": "prometheus"}},
                {"expr": "node_load5", "refId": "B", "legendFormat": "5m", "datasource": {"type": "prometheus", "uid": "prometheus"}},
                {"expr": "node_load15", "refId": "C", "legendFormat": "15m", "datasource": {"type": "prometheus", "uid": "prometheus"}},
            ],
        },
        {
            "type": "timeseries",
            "title": "Disk usage %",
            "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8},
            "id": 4,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": '(node_filesystem_size_bytes{fstype!~"tmpfs|overlay"} - node_filesystem_free_bytes{fstype!~"tmpfs|overlay"}) / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"} * 100',
                    "legendFormat": "{{mountpoint}}",
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                }
            ],
        },
    ],
    "refresh": "10s",
    "schemaVersion": 39,
    "tags": ["observability", "host"],
    "templating": {"list": []},
    "time": {"from": "now-1h", "to": "now"},
    "timepicker": {},
    "timezone": "browser",
    "title": "Host Overview (basic)",
    "uid": "host-overview-basic",
    "version": 1,
}

CONTAINERS = {
    "annotations": {"list": []},
    "editable": True,
    "fiscalYearStartMonth": 0,
    "graphTooltip": 0,
    "id": None,
    "links": [],
    "panels": [
        {
            "type": "timeseries",
            "title": "Container CPU (top)",
            "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
            "id": 1,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": 'topk(10, rate(container_cpu_usage_seconds_total{name!=""}[5m]))',
                    "legendFormat": "{{name}}",
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                }
            ],
        },
        {
            "type": "timeseries",
            "title": "Container Memory (RSS)",
            "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
            "id": 2,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": 'topk(10, container_memory_rss{name!=""})',
                    "legendFormat": "{{name}}",
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                }
            ],
        },
        {
            "type": "timeseries",
            "title": "Container Net I/O (bytes/s)",
            "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8},
            "id": 3,
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "fieldConfig": {"defaults": {}, "overrides": []},
            "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "single"}},
            "targets": [
                {
                    "expr": "sum by (name) (irate(container_network_receive_bytes_total[5m]))",
                    "legendFormat": "{{name}} RX",
                    "refId": "A",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                },
                {
                    "expr": "sum by (name) (irate(container_network_transmit_bytes_total[5m]))",
                    "legendFormat": "{{name}} TX",
                    "refId": "B",
                    "datasource": {"type": "prometheus", "uid": "prometheus"},
                },
            ],
        },
    ],
    "refresh": "10s",
    "schemaVersion": 39,
    "tags": ["observability", "containers"],
    "templating": {"list": []},
    "time": {"from": "now-1h", "to": "now"},
    "timepicker": {},
    "timezone": "browser",
    "title": "Containers Overview (basic)",
    "uid": "containers-overview-basic",
    "version": 1,
}


def scrub_community_dashboard(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    dash = data.get("dashboard", data)
    dash["id"] = None
    dash.pop("__inputs", None)
    dash.pop("__requires", None)
    dash["links"] = []

    def fix(obj):
        if not isinstance(obj, dict):
            return
        ds = obj.get("datasource")
        if isinstance(ds, dict):
            obj["datasource"] = {"type": "prometheus", "uid": "prometheus"}
        elif isinstance(ds, str) and ds.lower() in ("prometheus", "${datasource}", ""):
            obj["datasource"] = {"type": "prometheus", "uid": "prometheus"}
        for t in obj.get("targets", []) or []:
            if isinstance(t, dict):
                tds = t.get("datasource")
                if isinstance(tds, dict) or isinstance(tds, str):
                    t["datasource"] = {"type": "prometheus", "uid": "prometheus"}
        for nested in obj.get("panels", []) or []:
            fix(nested)
        for nested in obj.get("collapsed", []) or []:
            fix(nested)

    for panel in dash.get("panels", []) or []:
        fix(panel)

    for var in (dash.get("templating") or {}).get("list", []) or []:
        if var.get("type") == "datasource" or str(var.get("query", "")).lower() == "prometheus":
            var["current"] = {"text": "Prometheus", "value": "prometheus", "selected": True}
            var["query"] = "prometheus"
            var["name"] = var.get("name") or "datasource"

    path.write_text(json.dumps(dash, indent=2) + "\n", encoding="utf-8")
    print(f"scrubbed {path.name}")


def main() -> None:
    DASH_DIR.mkdir(parents=True, exist_ok=True)
    (DASH_DIR / "host-overview.json").write_text(json.dumps(HOST, indent=2) + "\n", encoding="utf-8")
    (DASH_DIR / "containers-overview.json").write_text(json.dumps(CONTAINERS, indent=2) + "\n", encoding="utf-8")
    print("wrote host-overview.json")
    print("wrote containers-overview.json")

    for p in sorted(DASH_DIR.glob("*.json")):
        if p.name in ("host-overview.json", "containers-overview.json"):
            continue
        try:
            scrub_community_dashboard(p)
        except Exception as exc:
            print(f"skip {p.name}: {exc}")


if __name__ == "__main__":
    main()
