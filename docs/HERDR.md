# Herdr + Hermes Agent — agenci CLI z trwałymi sesjami na serwerze

[Herdr](https://herdr.dev) ([repo](https://github.com/herdrdev/herdr), Apache-2.0) to
terminalowy multiplekser/runtime dla agentów (Claude Code, Codex, OpenCode, Hermes Agent…).
Agenci działają w panelach na serwerze i pracują dalej po zamknięciu laptopa; Herdr
pokazuje ich stan (working / blocked / idle / done) w zakładkach i sidebarze.

Role: `ansible/roles/herdr` i `ansible/roles/hermes` (tagi `herdr`, `hermes`, oba: `agents`;
playbook `playbooks/agents-only.yml`).

## Co instaluje rola

- Binarka `/usr/local/bin/herdr` w przypiętej wersji (`herdr_version`), weryfikowana SHA-256.
- Usługa systemd `herdr.service`: `herdr server` jako użytkownik `pawel`, start przy boocie.
  Socket: `~/.config/herdr/herdr.sock` — ten sam, którego używa `herdr` po SSH.
- Opcjonalnie integracje agentów (`herdr_integrations: [claude, hermes]` w `all.yml`).
  Integracja pozwala Herdrowi poprawnie rozpoznać stan agenta i po restarcie serwera
  wznowić rozmowę (`claude --resume <id>`, `hermes --resume <id>`).

Brak portów i reverse proxy — dostęp tylko po SSH (LAN / Tailscale).

## Hermes Agent

[Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research, MIT) to agent
z trwałą pamięcią i samodoskonalącymi się umiejętnościami. Rola `hermes` instaluje go
oficjalnym instalatorem z przypiętego tagu (`hermes_version`) do `~/.hermes`,
komenda `~/.local/bin/hermes`, bez Chromium i computer-use. Instalacja jest jednorazowa;
aktualizacja: `hermes update` na serwerze.

Klucz modelu: `hermes_env_secrets` w `secrets.yml` (np. `OPENROUTER_API_KEY` albo
`ANTHROPIC_API_KEY`) — rola dopisuje go do `~/.hermes/.env`. Wybór modelu: `hermes model`.
Sprawdzenie: `hermes doctor`.

Pierwszy deploy instaluje Hermesa przed Herdrem, więc integracja `hermes` w Herdr
(stan agenta + `hermes --resume` po restarcie) wpina się od razu.

### Hermes jako HQ w Herdr

W jednym panelu `hermes`, w sąsiednich `claude` / `codex`. Hermes może sterować
sąsiadami przez socket API Herdr (`herdr --help`, docs: https://herdr.dev/docs/socket-api/).

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
