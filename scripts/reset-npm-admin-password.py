#!/usr/bin/env python3
"""Reset hasła administratora Nginx Proxy Manager. Uruchom na VPS jako pawel."""
import json
import os
import secrets
import sqlite3
import string
import subprocess

DB = "/srv/nginx-proxy-manager/data/database.sqlite"


def main() -> None:
    password = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(18))
    digest = subprocess.check_output(
        [
            "docker",
            "exec",
            "-e",
            f"NEWPASS={password}",
            "nginx-proxy-manager",
            "node",
            "-e",
            'const bcrypt=require("bcrypt"); bcrypt.hash(process.env.NEWPASS,13).then(h=>process.stdout.write(h))',
        ],
        text=True,
    ).strip()
    if not digest.startswith("$2"):
        raise SystemExit("hash failed")

    con = sqlite3.connect(DB)
    row = con.execute("SELECT id, email FROM user WHERE is_deleted=0 ORDER BY id LIMIT 1").fetchone()
    if not row:
        raise SystemExit("no user")
    con.execute("UPDATE auth SET secret=? WHERE user_id=? AND type=?", (digest, row[0], "password"))
    con.commit()
    email = row[1]
    con.close()

    print(f"EMAIL {email}")
    print(f"PASS {password}")

    body = json.dumps({"identity": email, "secret": password})
    raw = subprocess.check_output(
        [
            "docker",
            "exec",
            "nginx-proxy-manager",
            "curl",
            "-s",
            "-m",
            "8",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            "-X",
            "POST",
            "http://127.0.0.1:81/api/tokens",
            "-H",
            "Content-Type: application/json",
            "-d",
            body,
        ],
        text=True,
    ).strip()
    print(f"LOGIN_TEST {raw}")


if __name__ == "__main__":
    if os.geteuid() != 0:
        raise SystemExit("uruchom przez: sudo python3 scripts/reset-npm-admin-password.py")
    main()
