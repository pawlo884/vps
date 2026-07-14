# PowerShell: skopiuj szablon Dockera do projektu React
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDir,

    [ValidateSet('vite', 'cra')]
    [string]$Type = 'vite',

    [string]$AppName = 'react-app'
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$TemplateDir = Join-Path $RepoRoot 'templates\react-app'

if (-not (Test-Path (Join-Path $TargetDir 'package.json'))) {
    Write-Error "Brak package.json w: $TargetDir"
}

$files = @('Dockerfile', 'nginx.conf', '.dockerignore', 'docker-compose.yml', 'docker-compose.local.yml')
foreach ($file in $files) {
    Copy-Item (Join-Path $TemplateDir $file) (Join-Path $TargetDir $file) -Force
    Write-Host "Skopiowano: $file"
}

$composePath = Join-Path $TargetDir 'docker-compose.yml'
$content = Get-Content $composePath -Raw
$content = $content -replace 'container_name: react-app', "container_name: $AppName"
$content = $content -replace 'react-app:', "${AppName}:"

if ($Type -eq 'cra') {
    $content = $content -replace 'BUILD_OUTPUT: dist', 'BUILD_OUTPUT: build'
}

Set-Content -Path $composePath -Value $content -NoNewline

$localComposePath = Join-Path $TargetDir 'docker-compose.local.yml'
$localContent = Get-Content $localComposePath -Raw
$localContent = $localContent -replace 'container_name: react-app-local', "container_name: ${AppName}-local"
$localContent = $localContent -replace 'react-app:', "${AppName}:"
if ($Type -eq 'cra') {
    $localContent = $localContent -replace 'BUILD_OUTPUT: dist', 'BUILD_OUTPUT: build'
}
Set-Content -Path $localComposePath -Value $localContent -NoNewline

Write-Host ""
Write-Host "Gotowe. W katalogu projektu:"
Write-Host "  Lokalnie:  docker compose -f docker-compose.local.yml up -d --build"
Write-Host "  Na VPS:    docker compose up -d --build"
Write-Host "  Adres:     http://localhost:8080 (lokalnie)"
