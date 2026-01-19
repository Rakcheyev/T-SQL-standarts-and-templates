[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipNavigation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $repoRoot
try {
    if (-not $SkipNavigation) {
        powershell -ExecutionPolicy Bypass -File .\scripts\generate_navigation_en.ps1
        powershell -ExecutionPolicy Bypass -File .\scripts\generate_navigation_uk.ps1
    }

    powershell -ExecutionPolicy Bypass -File .\scripts\sanity_check_lessons.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\check_markdown_links.ps1

    Write-Host "OK: verification succeeded." -ForegroundColor Green
} finally {
    Pop-Location
}
