# Starts the RUPP Eat development database (PostgreSQL 18, port 55432, localhost only).
# Data lives in database\pgdata. Credentials are in backend\.env (DB_PORT / DB_PASSWORD).
# Usage:  & .\database\start-db.ps1

$pgBin = 'C:\Program Files\PostgreSQL\18\bin'
$data = Join-Path $PSScriptRoot 'pgdata'
$log = Join-Path $PSScriptRoot 'pgdata.log'

& "$pgBin\pg_ctl.exe" -D $data status *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host 'RUPP Eat dev database is already running on 127.0.0.1:55432' -ForegroundColor Green
    return
}

& "$pgBin\pg_ctl.exe" -D $data -l $log -w start
if ($LASTEXITCODE -eq 0) {
    Write-Host 'RUPP Eat dev database started on 127.0.0.1:55432' -ForegroundColor Green
} else {
    Write-Host "Could not start the database. See $log" -ForegroundColor Red
}
