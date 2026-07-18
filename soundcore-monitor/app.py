#!/usr/bin/env python3
"""Prosty monitoring Soundcore: bateria + nagrania + odsłuch."""
from __future__ import annotations

import hmac
import os
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import streamlit as st

REC_DIR = Path(os.environ.get("SOUNDCORE_REC_DIR", "/home/pawel/Recordings/continuous"))
REFRESH_SEC = int(os.environ.get("SOUNDCORE_REFRESH_SEC", "10"))
TZ = ZoneInfo(os.environ.get("SOUNDCORE_TZ", "Europe/Warsaw"))
PREVIEW_DIR = Path(tempfile.gettempdir()) / "soundcore-previews"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
AUTH_USER = os.environ.get("SOUNDCORE_MONITOR_USER", "pawel")
AUTH_PASSWORD = os.environ.get("SOUNDCORE_MONITOR_PASSWORD", "")


def require_login() -> bool:
    """Proste logowanie user+hasło (session state)."""
    if not AUTH_PASSWORD:
        st.error("Brak SOUNDCORE_MONITOR_PASSWORD — ustaw hasło w serwisie.")
        st.stop()

    if st.session_state.get("authenticated"):
        with st.sidebar:
            st.caption(f"Zalogowany: **{st.session_state.get('auth_user', AUTH_USER)}**")
            if st.button("Wyloguj"):
                st.session_state.authenticated = False
                st.session_state.pop("auth_user", None)
                st.rerun()
        return True

    st.title("Soundcore Monitor — logowanie")
    with st.form("login"):
        user = st.text_input("Użytkownik", value=AUTH_USER)
        password = st.text_input("Hasło", type="password")
        ok = st.form_submit_button("Zaloguj")
    if ok:
        user_ok = hmac.compare_digest(user.strip(), AUTH_USER)
        pass_ok = hmac.compare_digest(password, AUTH_PASSWORD)
        if user_ok and pass_ok:
            st.session_state.authenticated = True
            st.session_state.auth_user = user.strip()
            st.rerun()
        st.error("Błędny login lub hasło")
    st.stop()
    return False


def now_local() -> datetime:
    return datetime.now(TZ)


def fmt_ts(ts: float) -> str:
    return datetime.fromtimestamp(ts, TZ).strftime("%Y-%m-%d %H:%M:%S")


def read_battery() -> tuple[int | None, bool | None]:
    """Zwraca (procent, connected). Preferuje D-Bus, fallback pliki healthcheck."""
    pct: int | None = None
    connected: bool | None = None
    try:
        import dbus

        bus = dbus.SystemBus()
        path = "/org/bluez/hci0/dev_18_9C_2C_20_D5_B8"
        props = dbus.Interface(
            bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties"
        )
        connected = bool(props.Get("org.bluez.Device1", "Connected"))
        try:
            pct = int(props.Get("org.bluez.Battery1", "Percentage"))
        except Exception:
            pass
    except Exception:
        pass

    if pct is None:
        batt_file = REC_DIR / "battery.pct"
        if batt_file.exists():
            try:
                pct = int(batt_file.read_text().strip())
            except Exception:
                pass

    if connected is None:
        status = REC_DIR / "health.status"
        if status.exists():
            text = status.read_text(errors="ignore")
            if "BT Connected" in text:
                connected = True
            elif "BT rozłączony" in text:
                connected = False

    return pct, connected


def read_health_lines() -> list[str]:
    status = REC_DIR / "health.status"
    if not status.exists():
        return []
    lines = status.read_text(errors="ignore").splitlines()
    return [ln for ln in lines if ln.startswith(("OK:", "WARN:", "FAIL:"))]


def list_recordings() -> list[dict]:
    rows: list[dict] = []
    if not REC_DIR.exists():
        return rows
    for p in sorted(REC_DIR.glob("vad-*.wav"), key=lambda x: x.stat().st_mtime, reverse=True):
        stt = p.stat()
        rows.append(
            {
                "path": p,
                "plik": p.name,
                "rozmiar_MB": round(stt.st_size / (1024 * 1024), 2),
                "bajty": stt.st_size,
                "mtime": fmt_ts(stt.st_mtime),
                "wiek_min": int((now_local().timestamp() - stt.st_mtime) / 60),
            }
        )
    return rows


def human_bytes(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024**2:
        return f"{n/1024:.1f} KiB"
    if n < 1024**3:
        return f"{n/1024**2:.1f} MiB"
    return f"{n/1024**3:.2f} GiB"


def make_preview(src: Path, seconds: int | None) -> Path | None:
    """Cały plik albo ostatnie N sekund (szybszy odsłuch dużych WAV)."""
    if not src.exists() or src.stat().st_size < 44:
        return None
    if seconds is None:
        return src

    out = PREVIEW_DIR / f"{src.stem}-last{seconds}s.wav"
    # odśwież preview gdy źródło urosło
    if out.exists() and out.stat().st_mtime >= src.stat().st_mtime:
        return out

    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-sseof", f"-{seconds}",
        "-i", str(src),
        "-ac", "1", "-ar", "16000",
        str(out),
    ]
    try:
        subprocess.run(cmd, check=True, timeout=60)
    except Exception:
        # fallback: cały plik jeśli sseof nie zadziała (za krótki plik)
        return src
    return out if out.exists() else src


st.set_page_config(page_title="Soundcore Monitor", page_icon="🎧", layout="wide")
require_login()
st.title("Soundcore Q11i — monitoring")

auto_refresh = st.checkbox("Auto-odświeżanie", value=True, help="Wyłącz przy odsłuchu — inaczej player się resetuje co 10s")
if auto_refresh:
    try:
        from streamlit_autorefresh import st_autorefresh

        st_autorefresh(interval=REFRESH_SEC * 1000, key="refresh")
    except Exception:
        st.caption(f"Odśwież ręcznie (co ~{REFRESH_SEC}s).")

pct, connected = read_battery()
rows = list_recordings()
total = sum(r["bajty"] for r in rows)
latest = rows[0] if rows else None

c1, c2, c3, c4 = st.columns(4)
with c1:
    if connected is True:
        st.metric("Bluetooth", "połączony")
    elif connected is False:
        st.metric("Bluetooth", "rozłączony")
    else:
        st.metric("Bluetooth", "nieznany")
with c2:
    st.metric("Bateria", f"{pct}%" if pct is not None else "n/a")
with c3:
    st.metric("Nagrania", f"{len(rows)} plików")
with c4:
    st.metric("Suma", human_bytes(total))

if pct is not None:
    st.progress(min(max(pct, 0), 100) / 100.0, text=f"Naładowanie {pct}%")

if latest:
    st.subheader("Najnowszy plik")
    st.write(
        f"**{latest['plik']}** — {latest['rozmiar_MB']} MB — "
        f"mtime {latest['mtime']} (wiek {latest['wiek_min']} min)"
    )

st.subheader("Odsłuch")
if rows:
    names = [r["plik"] for r in rows]
    pick = st.selectbox("Plik", names, index=0)
    chosen = next(r for r in rows if r["plik"] == pick)

    preview_opt = st.radio(
        "Zakres",
        options=["Ostatnie 30 s", "Ostatnie 60 s", "Ostatnie 3 min", "Cały plik"],
        horizontal=True,
        index=1,
    )
    seconds_map = {
        "Ostatnie 30 s": 30,
        "Ostatnie 60 s": 60,
        "Ostatnie 3 min": 180,
        "Cały plik": None,
    }
    seconds = seconds_map[preview_opt]

    if chosen["bajty"] > 80 * 1024 * 1024 and seconds is None:
        st.warning("Duży plik (>80 MB) — lepiej wybierz fragment, bo ładowanie może potrwać.")

    audio_path = make_preview(chosen["path"], seconds)
    if audio_path and audio_path.exists():
        st.caption(f"Odtwarzam: `{audio_path.name}` ({human_bytes(audio_path.stat().st_size)})")
        st.audio(str(audio_path), format="audio/wav")
    else:
        st.error("Nie udało się przygotować audio.")
else:
    st.info("Brak plików do odsłuchu.")

st.subheader("Wszystkie nagrania VAD")
if rows:
    st.dataframe(
        [{k: v for k, v in r.items() if k not in ("bajty", "path")} for r in rows],
        use_container_width=True,
        hide_index=True,
    )
else:
    st.info("Brak plików vad-*.wav")

health = read_health_lines()
if health:
    st.subheader("Ostatni healthcheck")
    for ln in health:
        if ln.startswith("FAIL:"):
            st.error(ln)
        elif ln.startswith("WARN:"):
            st.warning(ln)
        else:
            st.success(ln)

st.caption(
    f"Katalog: `{REC_DIR}` · odświeżanie ~{REFRESH_SEC}s · "
    f"{now_local().strftime('%H:%M:%S')} (Europe/Warsaw)"
)
