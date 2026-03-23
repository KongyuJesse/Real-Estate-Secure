# Database migration helper (PowerShell)
# Requires psql in PATH

param(
  [string]$DbHost = $env:PGHOST,
  [int]$Port = $env:PGPORT,
  [string]$Database = $env:PGDATABASE,
  [string]$User = $env:PGUSER,
  [string]$Password = $env:PGPASSWORD
)

if (-not $DbHost) { $DbHost = 'localhost' }
if (-not $Port) { $Port = 5432 }
if (-not $Database) { $Database = 'real_estate_secure' }
if (-not $User) { $User = 'postgres' }
if (-not $Password) { $Password = 'postgres' }

$env:PGPASSWORD = $Password

$root = Join-Path $PSScriptRoot '..'
$migrations = Join-Path $root 'database\migrations'
$seeds = Join-Path $root 'database\seeds'

Write-Host "Running migrations from $migrations"
Get-ChildItem $migrations -Filter '*.sql' | Sort-Object Name | ForEach-Object {
  Write-Host "Applying $($_.Name)"
  psql -h $DbHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $_.FullName
}

Write-Host "Running seeds from $seeds"
Get-ChildItem $seeds -Filter '*.sql' | Sort-Object Name | ForEach-Object {
  Write-Host "Seeding $($_.Name)"
  psql -h $DbHost -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f $_.FullName
}
