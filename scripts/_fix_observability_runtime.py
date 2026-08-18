#!/usr/bin/env python3
"""Diagnose and repair observability stack access + dashboards on VPS."""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STACK = Path("/home/pawel/stacks/observability")
NPM_DB = "/srv/nginx-proxy-manager/data/database.sqlite"
GRAFANA_DOMAIN = "grafana.sowa.ch"
GRAFANA_URL = "http://127.0.0.1:3000"


def sh(cmd: list[str] | str, check: bool = True) -> subprocess.CompletedProcess:
    print("+", cmd if isinstance(cmd, str) else " ".join(cmd))
    return subprocess.run(cmd, shell=isinstance(cmd, str), check=check, text=True, capture_output=True)


def grafana_request(path: str, method: str = "GET", data=None, auth: tuple[str, str] | None = None):
    import base64

    url = GRAFANA_URL + path
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if auth:
        token = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
        req.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            payload = json.loads(raw) if raw else None
        except Exception:
            payload = raw
        return e.code, payload


def get_grafana_auth() -> tuple[str, str]:
    # Prefer live container env; fallback to compose defaults
    out = sh(
        ["docker", "exec", "grafana", "printenv", "GF_SECURITY_ADMIN_USER", "GF_SECURITY_ADMIN_PASSWORD"],
        check=False,
    )
    lines = [ln.strip() for ln in (out.stdout or "").splitlines() if ln.strip()]
    if len(lines) >= 2:
        return lines[0], lines[1]
    return "admin", "admin"


def fix_dashboards_files() -> None:
    script = Path("/tmp/_fix_grafana_dashboards.py")
    if not script.exists():
        raise SystemExit("missing /tmp/_fix_grafana_dashboards.py")
    sh(["python3", str(script)])


def delete_conflicting_dashboards(auth: tuple[str, str]) -> None:
    code, items = grafana_request("/api/search?type=dash-db", auth=auth)
    if code != 200 or not isinstance(items, list):
        print("search failed", code, items)
        return
    wanted_titles = {
        "Host Overview (basic)",
        "Containers Overview (basic)",
    }
    wanted_uids = {"host-overview-basic", "containers-overview-basic"}
    for item in items:
        title = item.get("title")
        uid = item.get("uid")
        if title in wanted_titles or uid in wanted_uids:
            print(f"deleting dashboard {title} uid={uid} id={item.get('id')}")
            grafana_request(f"/api/dashboards/uid/{uid}", method="DELETE", auth=auth)


def update_compose_root_url() -> None:
    compose = STACK / "docker-compose.yml"
    text = compose.read_text(encoding="utf-8")
    old = 'GF_SERVER_ROOT_URL: "%(protocol)s://%(domain)s/"'
    new = f'GF_SERVER_ROOT_URL: "https://{GRAFANA_DOMAIN}/"'
    if "GF_SERVER_ROOT_URL:" not in text:
        print("compose missing GF_SERVER_ROOT_URL")
        return
    if new in text:
        print("ROOT_URL already set")
        return
    if old in text:
        text = text.replace(old, new)
    else:
        # replace any existing ROOT_URL line
        lines = []
        for line in text.splitlines():
            if "GF_SERVER_ROOT_URL:" in line:
                indent = line.split("GF_SERVER_ROOT_URL:")[0]
                lines.append(f'{indent}GF_SERVER_ROOT_URL: "https://{GRAFANA_DOMAIN}/"')
            else:
                lines.append(line)
        text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    compose.write_text(text, encoding="utf-8")
    print("updated GF_SERVER_ROOT_URL")


def recreate_grafana() -> None:
    subprocess.run(
        ["docker", "compose", "-p", "observability", "up", "-d", "--force-recreate", "grafana"],
        cwd=str(STACK),
        check=True,
    )


def wait_grafana() -> None:
    for _ in range(40):
        try:
            with urllib.request.urlopen(GRAFANA_URL + "/api/health", timeout=3) as resp:
                if resp.status == 200:
                    print("grafana healthy")
                    return
        except Exception:
            pass
        time.sleep(2)
    raise SystemExit("grafana not healthy")


def ensure_npm_proxy() -> None:
    """Insert grafana proxy host into NPM (HTTP + ACME path). SSL cert via NPM UI/API later if needed."""
    if not os.path.exists(NPM_DB):
        print("NPM db missing, skip proxy")
        return

    dump = subprocess.run(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            "SELECT id, domain_names, forward_host, forward_port, certificate_id, enabled FROM proxy_host;",
        ],
        text=True,
        capture_output=True,
        check=True,
    )
    rows = dump.stdout.strip().splitlines()
    existing_id = None
    for row in rows:
        if GRAFANA_DOMAIN in row:
            existing_id = row.split("|")[0]
            print("NPM proxy already exists:", row)
            break

    meta = json.dumps(
        {
            "letsencrypt_agree": True,
            "dns_challenge": False,
            "nginx_online": True,
            "nginx_err": None,
        }
    )

    if existing_id is None:
        sql = f"""
INSERT INTO proxy_host (
  created_on, modified_on, owner_user_id, is_deleted,
  domain_names, forward_host, forward_port, access_list_id, certificate_id,
  ssl_forced, caching_enabled, block_exploits, advanced_config,
  meta, allow_websocket_upgrade, http2_support, forward_scheme,
  enabled, locations, hsts_enabled, hsts_subdomains
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  '["{GRAFANA_DOMAIN}"]', 'grafana', 3000, 0, 0,
  0, 0, 1, '',
  '{meta}', 1, 0, 'http',
  1, '[]', 0, 0
);
SELECT last_insert_rowid();
"""
        out = subprocess.run(
            ["sudo", "sqlite3", NPM_DB, sql],
            text=True,
            capture_output=True,
            check=True,
        )
        new_id = out.stdout.strip().splitlines()[-1]
        print("inserted proxy_host id=", new_id)
    else:
        new_id = existing_id

    conf = f"""# ------------------------------------------------------------
# {GRAFANA_DOMAIN}
# ------------------------------------------------------------

server {{
  set $forward_scheme http;
  set $server         "grafana";
  set $port           3000;

  listen 80;
  listen [::]:80;

  server_name {GRAFANA_DOMAIN};

  include conf.d/include/letsencrypt-acme-challenge.conf;

  access_log /data/logs/proxy-host-{new_id}_access.log proxy;
  error_log /data/logs/proxy-host-{new_id}_error.log warn;

  location / {{
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    include conf.d/include/proxy.conf;
  }}

  include /data/nginx/custom/server_proxy[.]conf;
}}
"""
    conf_path = f"/srv/nginx-proxy-manager/data/nginx/proxy_host/{new_id}.conf"
    tmp = f"/tmp/npm-grafana-{new_id}.conf"
    Path(tmp).write_text(conf, encoding="utf-8")
    subprocess.run(["sudo", "cp", tmp, conf_path], check=True)
    subprocess.run(["sudo", "chmod", "644", conf_path], check=True)
    test = subprocess.run(
        ["docker", "exec", "nginx-proxy-manager", "nginx", "-t"],
        text=True,
        capture_output=True,
    )
    print("nginx -t:", test.returncode, (test.stderr or test.stdout)[-400:])
    if test.returncode == 0:
        reload = subprocess.run(
            ["docker", "exec", "nginx-proxy-manager", "nginx", "-s", "reload"],
            text=True,
            capture_output=True,
        )
        print("nginx reload:", reload.returncode, reload.stderr)
    else:
        print("SKIP reload due to nginx -t failure")


def check_prometheus() -> None:
    with urllib.request.urlopen("http://127.0.0.1:9090/api/v1/targets", timeout=10) as resp:
        data = json.load(resp)
    print("=== prom targets ===")
    for t in data["data"]["activeTargets"]:
        err = (t.get("lastError") or "")[:100]
        print(t["labels"].get("job"), t["health"], t["labels"].get("instance"), err)


def verify_grafana(auth: tuple[str, str]) -> None:
    code, items = grafana_request("/api/search", auth=auth)
    print("grafana search", code)
    if isinstance(items, list):
        for i in items:
            print("-", i.get("type"), i.get("title"), i.get("uid"))
    # wait a bit for provisioning
    time.sleep(5)
    code2, _ = grafana_request("/api/search", auth=auth)
    # check logs
    logs = sh(["docker", "logs", "grafana", "--tail", "30"], check=False)
    print(logs.stdout)
    print(logs.stderr)


def main() -> None:
    fix_dashboards_files()
    update_compose_root_url()
    auth = get_grafana_auth()
    print("grafana auth user:", auth[0])
    delete_conflicting_dashboards(auth)
    recreate_grafana()
    wait_grafana()
    # re-auth after recreate (password from env)
    auth = get_grafana_auth()
    time.sleep(8)
    verify_grafana(auth)
    check_prometheus()
    ensure_npm_proxy()
    print("DONE")


if __name__ == "__main__":
    main()
