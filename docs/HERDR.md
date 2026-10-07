# Herdr — agenci CLI z trwałymi sesjami na serwerze

[Herdr](https://herdr.dev) ([repo](https://github.com/herdrdev/herdr), Apache-2.0) to
terminalowy multiplekser/runtime dla agentów (Claude Code, Codex, OpenCode, Hermes Agent…).
Agenci działają w panelach na serwerze i pracują dalej po zamknięciu laptopa; Herdr
pokazuje ich stan (working / blocked / idle / done) w zakładkach i sidebarze.

Rola: `ansible/roles/herdr` (tag `herdr`, playbook `playbooks/herdr-only.yml`).

## Co instaluje rola

- Binarka `/usr/local/bin/herdr` w przypiętej wersji (`herdr_version`), weryfikowana SHA-256.
- Usługa systemd `herdr.service`: `herdr server` jako użytkownik `pawel`, start przy boocie.
  Socket: `~/.config/herdr/herdr.sock` — ten sam, którego używa `herdr` po SSH.
- Opcjonalnie integracje agentów (`herdr_integrations: [claude, hermes]` w `all.yml`).
  Integracja pozwala Herdrowi poprawnie rozpoznać stan agenta i po restarcie serwera
  wznowić rozmowę (`claude --resume <id>`, `hermes --resume <id>`).

Brak portów i reverse proxy — dostęp tylko po SSH (LAN / Tailscale).

## Jak używać

Na serwerze: `ssh pawel@<serwer>` → `herdr`. Odłączenie: `ctrl+b q` (agenci pracują dalej).

Z laptopa, gdy Herdr jest też lokalnie — serwer jako maszyna w tym samym oknie:

```bash
herdr machine add pawel@<serwer-tailscale>
herdr
```

## Co przetrwa

| Sytuacja | Procesy w panelach | Układ | Rozmowa agenta |
| --- | --- | --- | --- |
| Odłączenie / zerwane SSH | działają | wraca | trwa |
| Restart serwera / `systemctl restart herdr` | zatrzymane | wraca | wznawiana przez integrację |

Deploy z nową wersją binarki restartuje usługę (handler). Bez utraty paneli można
zamiast tego zaktualizować ręcznie: `herdr update --handoff`.

## Aktualizacja wersji

Zmień `herdr_version` i oba wpisy `herdr_checksums` (SHA-256 plików
`herdr-linux-x86_64` / `herdr-linux-aarch64` z GitHub Release), deploy z tagiem `herdr`.
