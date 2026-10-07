# Herd — agenci AI, rozmowy i kontekst w jednym miejscu

[Herd](https://github.com/NickGuAI/Herd) (AGPL-3.0) to panel nad Claude Code / Codex /
Gemini CLI / OpenCode: commanderzy, workerzy, pamięć, zatwierdzenia i historia rozmów
trzymane na serwerze, niezależnie od zakładki, maszyny czy sesji providera.

Rola: `ansible/roles/herd` (tag `herd`, playbook `playbooks/herd-only.yml`).

## Jak to jest postawione

- Obraz budowany na serwerze z repo Herd na przypiętym tagu (`herd_version`), bo nie ma
  oficjalnego obrazu w rejestrze. Kompilacja tylko gdy brak `herd-local:<wersja>`.
- Dane: `/srv/herd` → `/data/.herd` (SQLite, transkrypty, maszyny, hashe kluczy API).
- Port `127.0.0.1:20001`; kontener w sieci `nginx_proxy_manager_network`.
- `HERD_PROVIDER_EXECUTION_MODE=daemon-only`: kontener nie uruchamia CLI providerów.
  Robi to demon Herd na maszynie z zalogowanym `claude`/`codex` (serwer lub laptop).

## Pierwsze uruchomienie

1. `openssl rand -base64 48` → `herd_bootstrap_master_key` w `secrets.yml`
   (lokalnie i w GitLab `ANSIBLE_SECRETS`).
2. `herd_install: true` w `inventories/prod/group_vars/all.yml`.
3. Deploy: `DEPLOY_TAGS=herd` w pipeline albo
   `ansible-playbook -i inventories/prod/hosts.ini playbooks/herd-only.yml`.
   Pierwszy build trwa kilka minut.
4. NPM: Proxy Host `herd.sowa.ch` → `herd` : `20001`, **Websockets Support ON**,
   SSL, Access List **`internal-panels`** (LAN/Tailscale + hasło) — Herd steruje agentami
   z dostępem do powłoki, nie wystawiać publicznie.
5. Wejdź na `https://herd.sowa.ch`, zaloguj kluczem bootstrap, przejdź onboarding,
   utwórz stały klucz admina i odwołaj bootstrap (wygasa po 24 h).
6. Settings → Machines → token, potem na maszynie z CLI providerów:
   `herd connect https://herd.sowa.ch --token <token>`.

Sprawdzenie: `curl -fsS http://127.0.0.1:20001/api/health` na serwerze.

## Aktualizacja

Zmień `herd_version`, zrób kopię `/srv/herd` (Herd migruje schemat SQLite przy starcie,
starszy obraz nie zadziała na nowszym schemacie), deploy z tagiem `herd`.
