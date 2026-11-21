# Prompts for the PostgreSQL password (hidden input) and writes it to backend/.env
# as DB_PASSWORD="...". The password is never printed.
# Usage (from the backend folder):  & .\scripts\set-db-password.ps1

$envFile = Join-Path $PSScriptRoot '..\.env' | Resolve-Path
$secure = Read-Host 'PostgreSQL password for user postgres' -AsSecureString
$plain = [Net.NetworkCredential]::new('', $secure).Password

if ([string]::IsNullOrEmpty($plain)) {
    Write-Host 'No password entered. Nothing changed.' -ForegroundColor Yellow
    return
}

# Escape for a double-quoted dotenv value: backslash, double quote and dollar sign.
$escaped = $plain.Replace('\', '\\').Replace('"', '\"').Replace('$', '\$')

$lines = [IO.File]::ReadAllLines($envFile)
$found = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -like 'DB_PASSWORD=*') {
        $lines[$i] = 'DB_PASSWORD="' + $escaped + '"'
        $found = $true
    }
}
if (-not $found) { $lines += 'DB_PASSWORD="' + $escaped + '"' }

# UTF-8 without BOM (a BOM would break the first .env line)
[IO.File]::WriteAllLines($envFile, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
Write-Host "Saved DB_PASSWORD to $envFile" -ForegroundColor Green
