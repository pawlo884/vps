#!/usr/bin/env python3
"""Expose Prometheus UI via NPM at prometheus.sowa.ch."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

DOMAIN = "prometheus.sowa.ch"
NPM_DB = "/srv/nginx-proxy-manager/data/database.sqlite"
STACK = Path("/home/pawel/stacks/observability")


def sh(cmd, check=True):
    print("+", cmd if isinstance(cmd, str) else " ".join(cmd))
    return subprocess.run(cmd, shell=isinstance(cmd, str), text=True, capture_output=True, check=check)


def ensure_npm_network() -> None:
    # Attach prometheus container to NPM network if missing
    nets = sh(
        ["docker", "inspect", "prometheus", "--format", "{{json .NetworkSettings.Networks}}"]
    ).stdout
    if "nginx_proxy_manager_network" in nets:
        print("already on npm network")
    else:
        sh(["docker", "network", "connect", "nginx_proxy_manager_network", "prometheus"], check=False)
        print("connected prometheus to npm network")

    # Persist in compose
    compose = STACK / "docker-compose.yml"
    text = compose.read_text(encoding="utf-8")
    if "container_name: prometheus" not in text:
        print("compose missing prometheus service?")
        return
    # crude but safe: under prometheus service networks, ensure npm network listed
    if "nginx_proxy_manager_network" in text and text.count("nginx_proxy_manager_network") >= 1:
        # check prometheus block has it
        start = text.find("  prometheus:")
        end = text.find("\n  grafana:", start)
        block = text[start:end]
        if "nginx_proxy_manager_network" not in block:
            block2 = block.replace(
                "    networks:\n      - observability\n",
                "    networks:\n      - observability\n      - nginx_proxy_manager_network\n",
            )
            text = text[:start] + block2 + text[end:]
            compose.write_text(text, encoding="utf-8")
            print("updated compose networks for prometheus")
        else:
            print("compose already has npm net on prometheus")


def ensure_proxy() -> str:
    out = sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"SELECT id, domain_names, forward_host, forward_port, certificate_id FROM proxy_host WHERE domain_names LIKE '%{DOMAIN}%' AND is_deleted=0;",
        ]
    ).stdout.strip()
    if out:
        pid = out.splitlines()[-1].split("|")[0]
        print("proxy exists", out)
        return pid

    # Prefer reusing a working LE cert from grafana if present, else 0 (HTTP only)
    certs = sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            "SELECT id, domain_names, certificate_id FROM proxy_host WHERE domain_names LIKE '%grafana%' AND is_deleted=0;",
        ]
    ).stdout.strip()
    cert_id = 0
    ssl_forced = 0
    # Start HTTP-only; user can request cert in NPM UI (safer than wrong cert)
    meta = json.dumps({"nginx_online": True, "nginx_err": None})
    sql = f"""
INSERT INTO proxy_host (
  created_on, modified_on, owner_user_id, is_deleted,
  domain_names, forward_host, forward_port, access_list_id, certificate_id,
  ssl_forced, caching_enabled, block_exploits, advanced_config,
  meta, allow_websocket_upgrade, http2_support, forward_scheme,
  enabled, locations, hsts_enabled, hsts_subdomains
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  '["{DOMAIN}"]', 'prometheus', 9090, 0, {cert_id},
  {ssl_forced}, 0, 1, '',
  '{meta}', 1, 0, 'http',
  1, '[]', 0, 0
);
SELECT last_insert_rowid();
"""
    pid = sh(["sudo", "sqlite3", NPM_DB, sql]).stdout.strip().splitlines()[-1]
    print("inserted proxy id", pid)
    return pid


def write_conf(pid: str) -> None:
    # Check if grafana has a cert we can mirror pattern for SSL after user adds LE in UI.
    # For now HTTP + ACME challenge path so LE request works from NPM UI.
    row = sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"SELECT certificate_id, ssl_forced FROM proxy_host WHERE id={pid};",
        ]
    ).stdout.strip()
    cert_id, ssl_forced = (row.split("|") + ["0", "0"])[:2]
    cert_id = int(cert_id or 0)
    ssl_forced = int(ssl_forced or 0)

    if cert_id > 0:
        conf = f"""# ------------------------------------------------------------
# {DOMAIN}
# ------------------------------------------------------------

map $scheme $hsts_header {{
    https   "max-age=63072000;preload";
}}

server {{
  set $forward_scheme http;
  set $server         "prometheus";
  set $port           9090;

  listen 80;
  listen [::]:80;
  listen 443 ssl;
  listen [::]:443 ssl;

  server_name {DOMAIN};
  http2 off;

  include conf.d/include/letsencrypt-acme-challenge.conf;
  include conf.d/include/ssl-cache.conf;
  include conf.d/include/ssl-ciphers.conf;
  ssl_certificate /etc/letsencrypt/live/npm-{cert_id}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-{cert_id}/privkey.pem;

  include conf.d/include/force-ssl.conf;

  access_log /data/logs/proxy-host-{pid}_access.log proxy;
  error_log /data/logs/proxy-host-{pid}_error.log warn;

  location / {{
    include conf.d/include/proxy.conf;
  }}

  include /data/nginx/custom/server_proxy[.]conf;
}}
"""
    else:
        conf = f"""# ------------------------------------------------------------
# {DOMAIN}
# ------------------------------------------------------------

server {{
  set $forward_scheme http;
  set $server         "prometheus";
  set $port           9090;

  listen 80;
  listen [::]:80;

  server_name {DOMAIN};

  include conf.d/include/letsencrypt-acme-challenge.conf;

  access_log /data/logs/proxy-host-{pid}_access.log proxy;
  error_log /data/logs/proxy-host-{pid}_error.log warn;

  location / {{
    include conf.d/include/proxy.conf;
  }}

  include /data/nginx/custom/server_proxy[.]conf;
}}
"""
    tmp = f"/tmp/npm-prometheus-{pid}.conf"
    Path(tmp).write_text(conf, encoding="utf-8")
    sh(["sudo", "cp", tmp, f"/srv/nginx-proxy-manager/data/nginx/proxy_host/{pid}.conf"])
    test = sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-t"], check=False)
    print((test.stderr or test.stdout)[-300:])
    if test.returncode != 0:
        raise SystemExit("nginx -t failed")
    sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-s", "reload"])
    print("reloaded")


def verify() -> None:
    r = sh(
        [
            "docker",
            "exec",
            "nginx-proxy-manager",
            "curl",
            "-s",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            "http://prometheus:9090/-/healthy",
        ],
        check=False,
    )
    print("npm->prometheus", r.stdout)
    r2 = sh(
        ["curl", "-sI", "-H", f"Host: {DOMAIN}", "http://127.0.0.1/-/healthy"],
        check=False,
    )
    print(r2.stdout[:300])


def main():
    ensure_npm_network()
    pid = ensure_proxy()
    write_conf(pid)
    verify()
    print("DONE")
    print(f"NPM: {DOMAIN} -> prometheus:9090")
    print("Cloudflare: A record prometheus -> 212.127.93.27 (Proxied)")
    print("Potem w NPM: SSL -> Request new certificate")


if __name__ == "__main__":
    main()
