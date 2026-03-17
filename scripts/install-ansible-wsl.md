# Instalacja Ansible na Windows

## Problem
Ansible na Windows w Git Bash ma problemy z kompatybilnością. 

## Rozwiązania

### Opcja 1: WSL (Windows Subsystem for Linux) - NAJLEPSZE

1. **Zainstaluj WSL:**
   ```powershell
   # W PowerShell jako Administrator:
   wsl --install
   # Lub dla Ubuntu:
   wsl --install -d Ubuntu
   ```

2. **Po restarcie, w WSL zainstaluj Ansible:**
   ```bash
   sudo apt update
   sudo apt install ansible
   ```

3. **Użyj Ansible w WSL:**
   - Otwórz terminal WSL (Ubuntu)
   - Przejdź do katalogu projektu (możesz użyć `/mnt/c/Users/pawlo/Desktop/kodowanie/vps`)
   - Uruchom playbooki

### Opcja 2: Docker z Ansible

```bash
# Uruchom Ansible w kontenerze Docker
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -w /workspace \
  -v ~/.ssh:/root/.ssh:ro \
  cytopia/ansible:latest \
  ansible-playbook ansible/playbooks/site.yml
```

### Opcja 3: PowerShell (może działać lepiej)

Spróbuj uruchomić w PowerShell zamiast Git Bash:
```powershell
pip install ansible
ansible --version
```

### Opcja 4: Ansible w Python virtualenv

```bash
python -m venv venv-ansible
source venv-ansible/bin/activate  # W Git Bash
# Lub w PowerShell:
# venv-ansible\Scripts\Activate.ps1

pip install ansible
ansible --version
```

