#!/usr/bin/env python3
"""Fix NPM prometheus.sowa.ch to forward to docker container prometheus:9090."""
from __future__ import annotations

import subprocess
from pathlib import Path

DOMAIN = "prometheus.sowa.ch"
NPM_DB = "/srv/nginx-proxy-manager/data/database.sqlite"
PID = "18"


def sh(cmd, check=True):
    print("+", " ".join(cmd) if isinstance(cmd, list) else cmd)
    return subprocess.run(cmd, shell=isinstance(cmd, str), text=True, capture_output=True, check=check)


def main():
    # ensure network
    nets = sh(["docker", "inspect", "prometheus", "--format", "{{json .NetworkSettings.Networks}}"]).stdout
    if "nginx_proxy_manager_network" not in nets:
        sh(["docker", "network", "connect", "nginx_proxy_manager_network", "prometheus"], check=False)

    row = sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"SELECT id, domain_names, forward_host, forward_port, certificate_id, ssl_forced FROM proxy_host WHERE id={PID};",
        ]
    ).stdout.strip()
    print("before", row)
    parts = row.split("|")
    cert_id = int(parts[4] or 0)
    ssl_forced = int(parts[5] or 0)

    sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"UPDATE proxy_host SET forward_host='prometheus', forward_port=9090, forward_scheme='http', "
            f"modified_on=datetime('now') WHERE id={PID};",
        ]
    )
    print("after", sh(["sudo", "sqlite3", NPM_DB, f"SELECT id, forward_host, forward_port, certificate_id, ssl_forced FROM proxy_host WHERE id={PID};"]).stdout.strip())

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

  access_log /data/logs/proxy-host-{PID}_access.log proxy;
  error_log /data/logs/proxy-host-{PID}_error.log warn;

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

  access_log /data/logs/proxy-host-{PID}_access.log proxy;
  error_log /data/logs/proxy-host-{PID}_error.log warn;

  location / {{
    include conf.d/include/proxy.conf;
  }}

  include /data/nginx/custom/server_proxy[.]conf;
}}
"""

    tmp = f"/tmp/npm-prom-{PID}.conf"
    Path(tmp).write_text(conf, encoding="utf-8")
    sh(["sudo", "cp", tmp, f"/srv/nginx-proxy-manager/data/nginx/proxy_host/{PID}.conf"])

    # verify cert files exist
    if cert_id > 0:
        chk = sh(
            ["docker", "exec", "nginx-proxy-manager", "test", "-f", f"/etc/letsencrypt/live/npm-{cert_id}/fullchain.pem"],
            check=False,
        )
        print("cert exists", chk.returncode == 0)

    test = sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-t"], check=False)
    print((test.stderr or "")[-400:])
    if test.returncode != 0:
        raise SystemExit("nginx -t failed")
    sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-s", "reload"])

    print("npm->prom", sh(["docker", "exec", "nginx-proxy-manager", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://prometheus:9090/-/healthy"], check=False).stdout)
    print("--- http host ---")
    print(sh(["curl", "-skI", "-H", f"Host: {DOMAIN}", "http://127.0.0.1/-/healthy"], check=False).stdout[:400])
    print("--- https host ---")
    print(sh(["curl", "-skI", "-H", f"Host: {DOMAIN}", "https://127.0.0.1/-/healthy"], check=False).stdout[:400])
    print("--- public ---")
    print(sh(["curl", "-sI", f"https://{DOMAIN}/-/healthy"], check=False).stdout[:400])


if __name__ == "__main__":
    main()
