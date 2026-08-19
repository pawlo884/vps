#!/usr/bin/env python3
import sqlite3
import subprocess

db = "/srv/nginx-proxy-manager/data/database.sqlite"
con = sqlite3.connect(db)
cur = con.cursor()
cur.execute(
    "UPDATE proxy_host SET forward_host=? WHERE domain_names LIKE ? AND is_deleted=0",
    ("127.0.0.1", "%npm.sowa.ch%"),
)
cur.execute(
    "UPDATE proxy_host SET forward_host=? WHERE domain_names LIKE ? AND is_deleted=0",
    ("host.docker.internal", "%spy.sowa.ch%"),
)
con.commit()
rows = cur.execute(
    "SELECT id, domain_names, forward_host, forward_port FROM proxy_host "
    "WHERE is_deleted=0 AND (domain_names LIKE ? OR domain_names LIKE ?)",
    ("%npm.sowa.ch%", "%spy.sowa.ch%"),
).fetchall()
for row in rows:
    print(row)
con.close()
