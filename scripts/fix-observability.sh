#!/bin/bash
set -euo pipefail

STACK="/home/pawel/stacks/observability"
OLD="/root/stacks/observability"

mkdir -p "$STACK/prometheus" \
  "$STACK/grafana/provisioning/datasources" \
  "$STACK/grafana/provisioning/dashboards" \
  "$STACK/grafana/dashboards"

# Skopiuj dashboardy ze starego stacka
if [ -d /root/stacks/observability/grafana/dashboards ]; then
  sudo cp -a /root/stacks/observability/grafana/dashboards/. "$STACK/grafana/dashboards/" || true
fi

cat > "$STACK/prometheus/prometheus.yml" <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["prometheus:9090"]

  - job_name: node_exporter
    static_configs:
      - targets: ["node_exporter:9100"]

  - job_name: cadvisor
    static_configs:
      - targets: ["cadvisor:8080"]

  - job_name: postgres_nc
    static_configs:
      - targets: ["postgres_exporter_nc:9187"]
        labels:
          instance: "nc-postgres-1"
          db: "postgres"
EOF

cat > "$STACK/grafana/provisioning/datasources/datasource.yml" <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    uid: prometheus
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
EOF

cat > "$STACK/grafana/provisioning/dashboards/dashboards.yml" <<'EOF'
apiVersion: 1
providers:
  - name: 'preprovisioned'
    orgId: 1
    folder: 'Observability'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
EOF

cat > "$STACK/grafana/dashboards/host-overview.json" <<'EOF'
{
  "title": "Host Overview (basic)",
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "10s",
  "uid": "host-overview-basic",
  "panels": [
    {
      "type": "timeseries",
      "title": "CPU usage %",
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "datasource": { "type": "prometheus", "uid": "prometheus" }
        }
      ]
    },
    {
      "type": "timeseries",
      "title": "Memory used %",
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "datasource": { "type": "prometheus", "uid": "prometheus" }
        }
      ]
    },
    {
      "type": "timeseries",
      "title": "Load average",
      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "node_load1", "datasource": { "type": "prometheus", "uid": "prometheus" } },
        { "expr": "node_load5", "datasource": { "type": "prometheus", "uid": "prometheus" } },
        { "expr": "node_load15", "datasource": { "type": "prometheus", "uid": "prometheus" } }
      ]
    },
    {
      "type": "timeseries",
      "title": "Disk usage %",
      "gridPos": { "x": 12, "y": 8, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "(node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"} - node_filesystem_free_bytes{fstype!~\"tmpfs|overlay\"}) / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"} * 100",
          "legendFormat": "{{mountpoint}}",
          "datasource": { "type": "prometheus", "uid": "prometheus" }
        }
      ]
    }
  ]
}
EOF

cat > "$STACK/grafana/dashboards/containers-overview.json" <<'EOF'
{
  "title": "Containers Overview (basic)",
  "timezone": "browser",
  "schemaVersion": 39,
  "version": 1,
  "refresh": "10s",
  "uid": "containers-overview-basic",
  "panels": [
    {
      "type": "timeseries",
      "title": "Container CPU (top)",
      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "topk(10, rate(container_cpu_usage_seconds_total{name!=\"\"}[5m]))",
          "legendFormat": "{{name}}",
          "datasource": { "type": "prometheus", "uid": "prometheus" }
        }
      ]
    },
    {
      "type": "timeseries",
      "title": "Container Memory (RSS)",
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        {
          "expr": "topk(10, container_memory_rss{name!=\"\"})",
          "legendFormat": "{{name}}",
          "datasource": { "type": "prometheus", "uid": "prometheus" }
        }
      ]
    },
    {
      "type": "timeseries",
      "title": "Container Net I/O (bytes/s)",
      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "sum by (name) (irate(container_network_receive_bytes_total[5m]))", "legendFormat": "{{name}} RX", "datasource": { "type": "prometheus", "uid": "prometheus" } },
        { "expr": "sum by (name) (irate(container_network_transmit_bytes_total[5m]))", "legendFormat": "{{name}} TX", "datasource": { "type": "prometheus", "uid": "prometheus" } }
      ]
    }
  ]
}
EOF

# Wygeneruj compose z DSN z istniejÄ…cego kontenera (bez logowania hasĹ‚a)
python3 - <<'PY'
import json, subprocess
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit, quote

out = subprocess.check_output([
    "docker", "inspect", "observability-postgres_exporter_nc-1"
], text=True)
env = json.loads(out)[0]["Config"]["Env"]
dsn = next(e.split("=", 1)[1] for e in env if e.startswith("DATA_SOURCE_NAME="))

# WymuĹ› host nc-postgres-1, zachowaj user/pass/db
parts = urlsplit(dsn)
# netloc = user:pass@host:port
userinfo, hostinfo = parts.netloc.rsplit("@", 1)
new_netloc = f"{userinfo}@nc-postgres-1:5432"
dsn = urlunsplit((parts.scheme, new_netloc, parts.path, parts.query, parts.fragment))

# Escape for YAML double-quoted string
dsn_yaml = dsn.replace("\\", "\\\\").replace('"', '\\"')

compose = f"""services:
  prometheus:
    image: prom/prometheus:v3.2.1
    container_name: prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.retention.time=15d"
      - "--web.enable-lifecycle"
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus:ro
      - prom-data:/prometheus
    networks:
      - observability
    restart: unless-stopped

  grafana:
    image: grafana/grafana:11.5.2
    container_name: grafana
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_ROOT_URL: "%(protocol)s://%(domain)s/"
      GF_AUTH_ANONYMOUS_ENABLED: "false"
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    networks:
      - observability
      - nginx_proxy_manager_network
    depends_on:
      - prometheus
    restart: unless-stopped

  node_exporter:
    image: prom/node-exporter:v1.9.0
    container_name: node_exporter
    pid: host
    ports:
      - "127.0.0.1:9103:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--path.rootfs=/rootfs"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    networks:
      - observability
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.2
    container_name: cadvisor
    privileged: true
    devices:
      - /dev/kmsg
    ports:
      - "127.0.0.1:9102:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - observability
    restart: unless-stopped

  postgres_exporter_nc:
    image: prometheuscommunity/postgres-exporter:v0.16.0
    container_name: postgres_exporter_nc
    ports:
      - "127.0.0.1:9188:9187"
    networks:
      - observability
      - nc_dbnet
    environment:
      DATA_SOURCE_NAME: "{dsn_yaml}"
    restart: unless-stopped

volumes:
  prom-data:
    name: observability_prom-data
  grafana-data:
    name: observability_grafana-data

networks:
  observability:
    name: observability
    external: true
  nginx_proxy_manager_network:
    name: nginx_proxy_manager_network
    external: true
  nc_dbnet:
    name: nc_dbnet
    external: true
"""
Path("/home/pawel/stacks/observability/docker-compose.yml").write_text(compose)
print("compose written ok")
PY

docker network create observability 2>/dev/null || true

# Zatrzymaj stary stack
if [ -f "$OLD/docker-compose.yml" ]; then
  sudo docker compose -f "$OLD/docker-compose.yml" -p observability down --remove-orphans || true
fi

for c in observability-prometheus-1 observability-grafana-1 observability-node_exporter-1 \
         observability-cadvisor-1 observability-blackbox-1 \
         observability-postgres_exporter_shared-1 observability-postgres_exporter_nc-1 \
         prometheus grafana node_exporter cadvisor blackbox \
         postgres_exporter_nc postgres_exporter_shared; do
  docker rm -f "$c" 2>/dev/null || true
done

chown -R pawel:pawel "$STACK"
chmod 600 "$STACK/docker-compose.yml"

cd "$STACK"
docker compose -p observability pull
docker compose -p observability up -d

echo "=== waiting grafana ==="
for i in $(seq 1 40); do
  if curl -sf http://127.0.0.1:3000/api/health >/dev/null; then
    echo "grafana ok"
    break
  fi
  sleep 3
done

docker exec grafana grafana cli admin reset-admin-password admin >/dev/null || true

echo "=== waiting metrics ==="
sleep 8
echo "=== up ==="
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up' | python3 -c 'import sys,json; d=json.load(sys.stdin);
[print(r["metric"].get("job"), r["metric"].get("instance"), r["value"][1]) for r in d["data"]["result"]]'
echo "=== pg_up ==="
curl -s http://127.0.0.1:9188/metrics | grep '^pg_up' || true
echo "=== grafana login ==="
curl -s -o /dev/null -w '%{http_code}\n' -u admin:admin http://127.0.0.1:3000/api/search
echo "=== containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -iE 'prom|grafana|node_ex|cadvisor|postgres_ex' || true
