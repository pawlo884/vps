#!/bin/bash
# Skrypt do uruchamiania Ansible playbook z PC (SSH na VPS).
# Git Bash na Windows nie umie użyć venv z WSL — wtedy odpalamy Ansible w WSL.

set -e

cd "$(dirname "$0")/.." || exit 1

is_git_bash() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

if is_git_bash; then
  echo "Git Bash: Ansible przez WSL..."
  echo ""
  win_path="$(cygpath -w "$(pwd)")"
  repo_wsl="$(wsl wslpath -a "$win_path" | tr -d '\r')"
  extra=""
  for arg in "$@"; do
    extra+=" $(printf '%q' "$arg")"
  done
  exec wsl -e bash -lc "cd $(printf '%q' "$repo_wsl")/ansible && export ANSIBLE_ROLES_PATH=$(printf '%q' "$repo_wsl")/ansible/roles ANSIBLE_HOST_KEY_CHECKING=False && ansible-playbook -i inventories/prod/hosts.ini playbooks/site.yml -e ansible_ssh_private_key_file=/home/pawlo/.ssh/id_ed25519_wsl${extra}"
fi

# Linux / WSL: venv z bin/, nie Windowsowy Scripts/
if [ -f .venv/bin/activate ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

echo "Uruchamianie Ansible playbook na VPS..."
echo ""

if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible nie jest zainstalowany (ansible-playbook)."
    echo "Na Windows: WSL (sudo apt install ansible) albo .venv/bin z WSL."
    exit 1
fi

cd ansible || exit 1

ansible-playbook playbooks/site.yml "$@"

echo ""
echo "Zakonczono."
