# Ejecuta en orden: boilerplate, estructura completa y colección Postman

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent | Split-Path -Parent
Set-Location $repoRoot

$sqlPath = Join-Path $repoRoot "docs\scripts\BD\script_creacionBd.sql"
if (!(Test-Path $sqlPath)) {
  Write-Host "SQL file not found: $sqlPath" -ForegroundColor Red
  exit 1
}

$sqlContent = Get-Content -Raw $sqlPath
if ([string]::IsNullOrWhiteSpace($sqlContent)) {
  Write-Host "SQL file is empty. cargue el script de creación de la base de datos en script_creacionBd.sql" -ForegroundColor Yellow
  exit 0
}

$hasCreateTable = $sqlContent -match '(?i)\bCREATE\s+TABLE\b'
if (-not $hasCreateTable) {
  Write-Host "SQL file does not contain CREATE TABLE. No se ejecuta ningun comando." -ForegroundColor Yellow
  exit 0
}

$cmds = @(
  'node docs/scripts/generate-base-boilerplate.js',
  'node docs/scripts/generate-full-structure-all.js docs/scripts/BD/script_creacionBd.sql',
  'node docs/scripts/generate-postman-collection.js docs/scripts/BD/script_creacionBd.sql'
)

foreach ($cmd in $cmds) {
  Write-Host "Ejecutando: $cmd" -ForegroundColor Cyan
  & powershell -NoProfile -Command $cmd
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Write-Host "Error al ejecutar: $cmd" -ForegroundColor Red
    exit $exitCode
  }
}
