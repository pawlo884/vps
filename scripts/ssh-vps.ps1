# PowerShell: polaczenie z VPS przez SSH
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$HostsIni = Join-Path $RepoRoot 'ansible\inventories\prod\hosts.ini'

if (-not (Test-Path $HostsIni)) {
    Write-Error "Brak pliku hosts.ini: $HostsIni"
}

$content = Get-Content $HostsIni -Raw
if ($content -match 'ansible_host=(\S+)') { $VpsHost = $Matches[1] } else { Write-Error 'Nie znaleziono ansible_host w hosts.ini' }
if ($content -match 'ansible_user=(\S+)') { $VpsUser = $Matches[1] } else { Write-Error 'Nie znaleziono ansible_user w hosts.ini' }

Write-Host "Laczenie z VPS..."
Write-Host "  Host: $VpsHost"
Write-Host "  User: $VpsUser"
Write-Host ""

ssh "$VpsUser@$VpsHost"
