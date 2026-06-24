$ErrorActionPreference = 'Stop'

$postgresBin = 'F:\postgresql\pgsql\bin'
$dataDir = 'F:\postgresql\data'
$logFile = 'F:\postgresql\logs\postgresql.log'
$appExe = 'F:\flutter\flutter_app\build\windows\x64\runner\Release\flutter_app.exe'
$appDir = Split-Path -Parent $appExe

$pgCtl = Join-Path $postgresBin 'pg_ctl.exe'
$psql = Join-Path $postgresBin 'psql.exe'

& $pgCtl -D $dataDir status *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Starting PostgreSQL...'
  & $pgCtl -D $dataDir -l $logFile start | Out-Host
  Start-Sleep -Seconds 2
}

$env:PGPASSWORD = 'postgres'
& $psql -h 127.0.0.1 -p 5432 -U postgres -d coffee_viet_24h -c 'SELECT 1;' *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'PostgreSQL is not ready on 127.0.0.1:5432.'
}

Start-Process -FilePath $appExe -WorkingDirectory $appDir
Write-Host 'Coffee app started.'
