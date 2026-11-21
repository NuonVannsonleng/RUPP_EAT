# Stops the RUPP Eat development database.
# Usage:  & .\database\stop-db.ps1

$pgBin = 'C:\Program Files\PostgreSQL\18\bin'
& "$pgBin\pg_ctl.exe" -D (Join-Path $PSScriptRoot 'pgdata') -m fast stop
