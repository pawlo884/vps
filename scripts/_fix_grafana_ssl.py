#!/usr/bin/env python3
"""Issue LE (or self-signed fallback) cert for grafana.sowa.ch and enable HTTPS in NPM."""
from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path

DOMAIN = "grafana.sowa.ch"
NPM_DB = "/srv/nginx-proxy-manager/data/database.sqlite"
EMAIL = "admin@sowa.ch"


def sh(cmd, check=True):
    print("+", " ".join(cmd) if isinstance(cmd, list) else cmd)
    return subprocess.run(cmd, shell=isinstance(cmd, str), text=True, capture_output=True, check=check)


def proxy_id() -> str:
    out = sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"SELECT id FROM proxy_host WHERE domain_names LIKE '%{DOMAIN}%' AND is_deleted=0;",
        ]
    ).stdout.strip()
    if not out:
        raise SystemExit("proxy host missing")
    return out.splitlines()[-1]


def try_letsencrypt() -> int | None:
    """Request cert via certbot in NPM container; return new certificate row id."""
    # webroot used by NPM
    cmd = [
        "docker",
        "exec",
        "nginx-proxy-manager",
        "certbot",
        "certonly",
        "--non-interactive",
        "--agree-tos",
        "--email",
        EMAIL,
        "--webroot",
        "-w",
        "/data/letsencrypt-acme-challenge",
        "-d",
        DOMAIN,
        "--cert-name",
        f"npm-grafana-{DOMAIN}",
    ]
    r = sh(cmd, check=False)
    print(r.stdout[-800:] if r.stdout else "")
    print(r.stderr[-800:] if r.stderr else "")
    if r.returncode != 0:
        return None

    # Find where certbot put files
    live = sh(
        ["docker", "exec", "nginx-proxy-manager", "sh", "-c", "ls -d /etc/letsencrypt/live/*grafana* /etc/letsencrypt/live/npm-grafana* 2>/dev/null | head -5"],
        check=False,
    ).stdout.strip()
    print("live dirs:", live)
    # NPM expects /etc/letsencrypt/live/npm-<id>/
    # Insert certificate row first to get id, then symlink/copy
    meta = json.dumps({"letsencrypt_email": EMAIL, "letsencrypt_agree": True, "dns_challenge": False})
    sql = f"""
INSERT INTO certificate (
  created_on, modified_on, owner_user_id, is_deleted,
  provider, nice_name, domain_names, expires_on, meta
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  'letsencrypt', '{DOMAIN}', '["{DOMAIN}"]', datetime('now', '+90 days'), '{meta}'
);
SELECT last_insert_rowid();
"""
    cert_id = sh(["sudo", "sqlite3", NPM_DB, sql]).stdout.strip().splitlines()[-1]
    print("certificate id", cert_id)

    # Locate actual certbot files
    find = sh(
        [
            "docker",
            "exec",
            "nginx-proxy-manager",
            "sh",
            "-c",
            f"ls -d /etc/letsencrypt/live/{DOMAIN} /etc/letsencrypt/live/npm-grafana-{DOMAIN} 2>/dev/null; ls /etc/letsencrypt/live | head",
        ],
        check=False,
    ).stdout
    print(find)

    src = None
    for candidate in (f"/etc/letsencrypt/live/{DOMAIN}", f"/etc/letsencrypt/live/npm-grafana-{DOMAIN}"):
        chk = sh(["docker", "exec", "nginx-proxy-manager", "test", "-f", f"{candidate}/fullchain.pem"], check=False)
        if chk.returncode == 0:
            src = candidate
            break
    if not src:
        # fallback: newest live dir
        src = sh(
            ["docker", "exec", "nginx-proxy-manager", "sh", "-c", "ls -1dt /etc/letsencrypt/live/*/ | head -1"],
            check=False,
        ).stdout.strip().rstrip("/")
    dst = f"/etc/letsencrypt/live/npm-{cert_id}"
    sh(["docker", "exec", "nginx-proxy-manager", "sh", "-c", f"rm -rf {dst}; mkdir -p {dst}; cp -L {src}/fullchain.pem {src}/privkey.pem {src}/cert.pem {src}/chain.pem {dst}/ 2>/dev/null || cp -L {src}/fullchain.pem {src}/privkey.pem {dst}/"])
    return int(cert_id)


def self_signed(cert_id_hint: int | None = None) -> int:
    meta = json.dumps({"self_signed": True})
    sql = f"""
INSERT INTO certificate (
  created_on, modified_on, owner_user_id, is_deleted,
  provider, nice_name, domain_names, expires_on, meta
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  'other', '{DOMAIN} (self-signed)', '["{DOMAIN}"]', datetime('now', '+3650 days'), '{meta}'
);
SELECT last_insert_rowid();
"""
    cert_id = sh(["sudo", "sqlite3", NPM_DB, sql]).stdout.strip().splitlines()[-1]
    dst = f"/etc/letsencrypt/live/npm-{cert_id}"
    sh(
        [
            "docker",
            "exec",
            "nginx-proxy-manager",
            "sh",
            "-c",
            f"mkdir -p {dst} && openssl req -x509 -nodes -newkey rsa:2048 -days 3650 "
            f"-keyout {dst}/privkey.pem -out {dst}/fullchain.pem "
            f"-subj '/CN={DOMAIN}'",
        ]
    )
    return int(cert_id)


def write_ssl_conf(pid: str, cert_id: int) -> None:
    conf = f"""# ------------------------------------------------------------
# {DOMAIN}
# ------------------------------------------------------------

map $scheme $hsts_header {{
    https   "max-age=63072000;preload";
}}

server {{
  set $forward_scheme http;
  set $server         "grafana";
  set $port           3000;

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
    tmp = f"/tmp/npm-grafana-{pid}.conf"
    Path(tmp).write_text(conf, encoding="utf-8")
    sh(["sudo", "cp", tmp, f"/srv/nginx-proxy-manager/data/nginx/proxy_host/{pid}.conf"])
    sh(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"UPDATE proxy_host SET certificate_id={cert_id}, ssl_forced=1, hsts_enabled=1, modified_on=datetime('now') WHERE id={pid};",
        ]
    )
    test = sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-t"], check=False)
    print(test.stderr[-400:] if test.stderr else test.stdout)
    if test.returncode != 0:
        raise SystemExit("nginx -t failed")
    sh(["docker", "exec", "nginx-proxy-manager", "nginx", "-s", "reload"])


def main() -> None:
    pid = proxy_id()
    print("proxy id", pid)
    cert_id = try_letsencrypt()
    if cert_id is None:
        print("LE failed, using self-signed (Cloudflare Full OK, Full Strict needs LE)")
        cert_id = self_signed()
    print("using cert", cert_id)
    write_ssl_conf(pid, cert_id)
    time.sleep(2)
    r = sh(["curl", "-skI", f"https://127.0.0.1/login", "-H", f"Host: {DOMAIN}"], check=False)
    print(r.stdout[:500])
    r2 = sh(["curl", "-sI", f"https://{DOMAIN}/login"], check=False)
    print("public:", r2.stdout[:500])


if __name__ == "__main__":
    main()
