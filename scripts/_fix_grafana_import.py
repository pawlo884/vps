#!/usr/bin/env python3
"""Import Grafana dashboards via API and fix NPM grafana proxy conf."""
from __future__ import annotations

import base64
import json
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

STACK = Path("/home/pawel/stacks/observability")
DASH_DIR = STACK / "grafana" / "dashboards"
PROV_DIR = STACK / "grafana" / "provisioning" / "dashboards"
GRAFANA = "http://127.0.0.1:3000"
DOMAIN = "grafana.sowa.ch"
NPM_DB = "/srv/nginx-proxy-manager/data/database.sqlite"


def auth_header() -> dict[str, str]:
    out = subprocess.check_output(
        ["docker", "exec", "grafana", "printenv", "GF_SECURITY_ADMIN_USER", "GF_SECURITY_ADMIN_PASSWORD"],
        text=True,
    )
    lines = [ln.strip() for ln in out.splitlines() if ln.strip()]
    user, password = lines[0], lines[1]
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}


def api(method: str, path: str, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(GRAFANA + path, data=data, method=method, headers=auth_header())
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            body = json.loads(raw) if raw else None
        except Exception:
            body = raw
        return e.code, body


def disable_file_provisioning() -> None:
    """Stop Grafana from repeatedly failing on file dashboards; keep folder for API imports."""
    # Move provisioned JSON out of the watched path, keep copies for API import
    archive = STACK / "grafana" / "dashboard-src"
    archive.mkdir(parents=True, exist_ok=True)
    for p in DASH_DIR.glob("*.json"):
        target = archive / p.name
        target.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
        p.unlink()
        print("archived", p.name)

    # Empty provider path stays, but no files -> no errors
    yml = """apiVersion: 1
providers: []
"""
    PROV_DIR.mkdir(parents=True, exist_ok=True)
    (PROV_DIR / "dashboards.yml").write_text(yml, encoding="utf-8")
    print("disabled file dashboard providers")


def ensure_folder(headers_ok: bool = True) -> int | None:
    code, folders = api("GET", "/api/folders")
    if code == 200 and isinstance(folders, list):
        for f in folders:
            if f.get("title") == "Observability" or f.get("uid") == "observability":
                return f.get("id")
    code, created = api(
        "POST",
        "/api/folders",
        {"uid": "observability", "title": "Observability"},
    )
    print("create folder", code, created)
    if code in (200, 201) and isinstance(created, dict):
        return created.get("id")
    return None


def delete_all_matching() -> None:
    code, items = api("GET", "/api/search?type=dash-db")
    if code != 200 or not isinstance(items, list):
        print("search failed", code, items)
        return
    for item in items:
        title = item.get("title") or ""
        uid = item.get("uid") or ""
        if (
            title.startswith("Host Overview")
            or title.startswith("Containers Overview")
            or title.startswith("PostgreSQL")
            or uid in {"host-overview-basic", "containers-overview-basic", "000000039"}
        ):
            c, body = api("DELETE", f"/api/dashboards/uid/{uid}")
            print("delete", uid, title, c)


def import_from_archive(folder_id: int | None) -> None:
    archive = STACK / "grafana" / "dashboard-src"
    # Ensure fresh fixed JSON
    subprocess.check_call(["python3", "/tmp/_fix_grafana_dashboards.py"])
    # Copy fixed files into archive
    src_dir = DASH_DIR
    # _fix writes into DASH_DIR; move again into archive then clear DASH_DIR
    for p in list(src_dir.glob("*.json")):
        (archive / p.name).write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
        p.unlink()

    for p in sorted(archive.glob("*.json")):
        dash = json.loads(p.read_text(encoding="utf-8"))
        dash["id"] = None
        payload = {
            "dashboard": dash,
            "overwrite": True,
            "message": "imported by observability fix",
        }
        if folder_id is not None:
            payload["folderId"] = folder_id
        code, body = api("POST", "/api/dashboards/db", payload)
        print("import", p.name, code, body if code >= 400 else (body or {}).get("status") or (body or {}).get("uid"))


def add_feature_toggle_safe() -> None:
    compose = STACK / "docker-compose.yml"
    text = compose.read_text(encoding="utf-8")
    needle = "GF_AUTH_ANONYMOUS_ENABLED:"
    extra = '      GF_FEATURE_TOGGLES_DISABLE: "kubernetesDashboards dashboardAPIServer"'
    if "GF_FEATURE_TOGGLES_DISABLE" in text:
        print("feature toggle already set")
        return
    lines = []
    for line in text.splitlines():
        lines.append(line)
        if needle in line:
            lines.append(extra)
    compose.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("added GF_FEATURE_TOGGLES_DISABLE")
    subprocess.check_call(
        ["docker", "compose", "-p", "observability", "up", "-d", "--force-recreate", "grafana"],
        cwd=str(STACK),
    )
    for _ in range(40):
        try:
            with urllib.request.urlopen(GRAFANA + "/api/health", timeout=3) as r:
                if r.status == 200:
                    print("grafana up")
                    return
        except Exception:
            time.sleep(2)
    raise SystemExit("grafana down")


def fix_npm() -> None:
    out = subprocess.check_output(
        [
            "sudo",
            "sqlite3",
            NPM_DB,
            f"SELECT id FROM proxy_host WHERE domain_names LIKE '%{DOMAIN}%' AND is_deleted=0;",
        ],
        text=True,
    ).strip()
    if not out:
        print("no npm row for grafana")
        return
    new_id = out.splitlines()[-1]
    conf = f"""# ------------------------------------------------------------
# {DOMAIN}
# ------------------------------------------------------------

server {{
  set $forward_scheme http;
  set $server         "grafana";
  set $port           3000;

  listen 80;
  listen [::]:80;

  server_name {DOMAIN};

  include conf.d/include/letsencrypt-acme-challenge.conf;

  access_log /data/logs/proxy-host-{new_id}_access.log proxy;
  error_log /data/logs/proxy-host-{new_id}_error.log warn;

  location / {{
    include conf.d/include/proxy.conf;
  }}

  include /data/nginx/custom/server_proxy[.]conf;
}}
"""
    tmp = f"/tmp/npm-grafana-{new_id}.conf"
    path = f"/srv/nginx-proxy-manager/data/nginx/proxy_host/{new_id}.conf"
    Path(tmp).write_text(conf, encoding="utf-8")
    subprocess.check_call(["sudo", "cp", tmp, path])
    test = subprocess.run(
        ["docker", "exec", "nginx-proxy-manager", "nginx", "-t"],
        text=True,
        capture_output=True,
    )
    print("nginx -t", test.returncode, (test.stderr or "")[-300:])
    if test.returncode == 0:
        subprocess.check_call(["docker", "exec", "nginx-proxy-manager", "nginx", "-s", "reload"])
        print("nginx reloaded")


def main() -> None:
    # First stop file provisioning failures
    disable_file_provisioning()
    add_feature_toggle_safe()
    delete_all_matching()
    folder_id = ensure_folder()
    import_from_archive(folder_id)
    code, items = api("GET", "/api/search")
    print("=== search ===")
    if isinstance(items, list):
        for i in items:
            print(i.get("type"), i.get("title"), i.get("uid"), i.get("folderTitle"))
    fix_npm()
    # local proxy check via docker network
    r = subprocess.run(
        ["docker", "exec", "nginx-proxy-manager", "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://grafana:3000/login"],
        text=True,
        capture_output=True,
    )
    print("npm->grafana", r.stdout, r.stderr)
    r2 = subprocess.run(
        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-H", f"Host: {DOMAIN}", "http://127.0.0.1/login"],
        text=True,
        capture_output=True,
    )
    print("host-header via :80", r2.stdout)


if __name__ == "__main__":
    main()
