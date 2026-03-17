# PowerShell: status VPS (używa venv)
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$VenvActivate = Join-Path $RepoRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path $VenvActivate)) {
    Write-Error "Brak venv. Utwórz: py -3.11 -m venv .venv"
}
. $VenvActivate

Set-Location (Join-Path $RepoRoot 'ansible')

Write-Host "🖥️  System:"
ansible all -m setup -a "gather_subset=min" | Select-String -Pattern "ansible_distribution|ansible_distribution_version|ansible_processor_vcpus|ansible_memtotal_mb"

Write-Host "`n💾 Dysk:"
ansible all -m shell -a "df -h /" | Select-Object -Last 1

Write-Host "`n🐳 Docker:"
ansible all -m shell -a "docker --version 2>$null || echo 'Docker nie zainstalowany'"

Write-Host "`n🔌 Uruchomione kontenery:"
ansible all -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}' 2>$null || echo 'Brak kontenerów'"

Write-Host "`n🌐 Nginx:"
ansible all -m shell -a "systemctl is-active nginx 2>$null || echo 'Nginx nieaktywny'"

Write-Host "`n🔥 Firewall:"
ansible all -m shell -a "sudo ufw status | head -5"
