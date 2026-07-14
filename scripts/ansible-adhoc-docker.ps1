# Ad-hoc Ansible przez Docker (ping, shell, setup itp.)
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Module,

    [Parameter(Position = 1)]
    [string]$Args = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$KeyPath = Join-Path $env:USERPROFILE '.ssh\id_ed25519'

if (-not (Test-Path $KeyPath)) {
    Write-Error "Brak klucza SSH: $KeyPath"
}

$moduleArgs = if ($Args) { "-a '$Args'" } else { '' }

docker run --rm `
    -v "${RepoRoot}:/workspace" `
    -v "${KeyPath}:/mnt/key:ro" `
    -e ANSIBLE_ROLES_PATH=/workspace/ansible/roles `
    -w /workspace/ansible `
    cytopia/ansible:latest `
    sh -c "apk add --no-cache openssh-client >/dev/null 2>&1 && cp /mnt/key /tmp/key && chmod 600 /tmp/key && ansible -i inventories/prod/hosts.ini all -m $Module $moduleArgs -e ansible_ssh_private_key_file=/tmp/key"
