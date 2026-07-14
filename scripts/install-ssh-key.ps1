# PowerShell: jednorazowe skopiowanie klucza SSH na VPS (wymaga hasla)
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$HostsIni = Join-Path $RepoRoot 'ansible\inventories\prod\hosts.ini'
$PubKeyPath = Join-Path $env:USERPROFILE '.ssh\id_ed25519.pub'

if (-not (Test-Path $PubKeyPath)) {
    Write-Error "Brak klucza publicznego. Wygeneruj: ssh-keygen -t ed25519 -f `"$env:USERPROFILE\.ssh\id_ed25519`""
}

$content = Get-Content $HostsIni -Raw
if ($content -match 'ansible_host=(\S+)') { $VpsHost = $Matches[1] } else { Write-Error 'Nie znaleziono ansible_host w hosts.ini' }
if ($content -match 'ansible_user=(\S+)') { $VpsUser = $Matches[1] } else { Write-Error 'Nie znaleziono ansible_user w hosts.ini' }

$pubKey = Get-Content $PubKeyPath -Raw
$remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$($pubKey.Trim())' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"

Write-Host "Kopiowanie klucza SSH na VPS ($VpsUser@$VpsHost)..."
Write-Host "Podaj haslo SSH gdy zostaniesz poproszony (jednorazowo)."
Write-Host ""

ssh "$VpsUser@$VpsHost" $remoteCmd

Write-Host ""
Write-Host "Test polaczenia bez hasla..."
ssh -o BatchMode=yes "$VpsUser@$VpsHost" "echo Polaczenie OK - klucz dziala!"
