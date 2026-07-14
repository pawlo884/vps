# Ansible przez Docker (Windows: natywny ansible wymaga UTF-8 locale)
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$KeyPath = Join-Path $env:USERPROFILE '.ssh\id_ed25519'

if (-not (Test-Path $KeyPath)) {
    Write-Error "Brak klucza SSH: $KeyPath"
}

$playbookArgs = if ($ExtraArgs.Count -gt 0) { $ExtraArgs -join ' ' } else { 'playbooks/site.yml' }

docker run --rm `
    -v "${RepoRoot}:/workspace" `
    -v "${KeyPath}:/mnt/key:ro" `
    -e ANSIBLE_ROLES_PATH=/workspace/ansible/roles `
    -w /workspace/ansible `
    cytopia/ansible:latest `
    sh -c "apk add --no-cache openssh-client >/dev/null 2>&1 && cp /mnt/key /tmp/key && chmod 600 /tmp/key && ansible-playbook -i inventories/prod/hosts.ini $playbookArgs -e ansible_ssh_private_key_file=/tmp/key"
