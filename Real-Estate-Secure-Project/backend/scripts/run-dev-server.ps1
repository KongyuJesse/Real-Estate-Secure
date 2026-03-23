$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location (Join-Path $projectRoot 'backend')

& 'C:\Program Files\nodejs\node.exe' 'src/server.js'
