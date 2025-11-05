# PowerShell: dry-run ansible (uzywa venv)
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$VenvActivate = Join-Path $RepoRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path $VenvActivate)) {
  Write-Error "Brak venv. Utworz: py -3.11 -m venv .venv"
}
. $VenvActivate

Set-Location (Join-Path $RepoRoot 'ansible')

python -m ansible.playbook playbooks/site.yml --check --diff @Args
