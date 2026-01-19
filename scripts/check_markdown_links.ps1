[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root = "",

    [Parameter(Mandatory = $false)]
    [string[]]$IncludeGlobs = @(
        "*.md",
        "course/lessons/*.md",
        "i18n/uk/course/lessons/*.md"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    if ($Root -and $Root.Trim().Length -gt 0) {
        return (Resolve-Path -LiteralPath $Root)
    }
    return (Resolve-Path (Join-Path $PSScriptRoot '..'))
}

function Get-MarkdownFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $files = New-Object System.Collections.Generic.List[string]

    foreach ($glob in $IncludeGlobs) {
        # If the glob is just "*.md", search repo root recursively.
        if ($glob -eq '*.md') {
            Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter '*.md' |
                Where-Object {
                    $_.FullName -notmatch '[\\/]archive[\\/]' -and
                    $_.FullName -notmatch '[\\/]backups[\\/]' -and
                    $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                    $_.FullName -notmatch '[\\/]node_modules[\\/]' -and
                    $_.FullName -notmatch '[\\/]\.venv[\\/]' -and
                    $_.FullName -notmatch '[\\/]venv[\\/]'
                } |
                ForEach-Object { $files.Add($_.FullName) }
            continue
        }

        $path = Join-Path $RepoRoot $glob
        $dir = Split-Path -Parent $path
        $leaf = Split-Path -Leaf $path
        if (Test-Path -LiteralPath $dir) {
            Get-ChildItem -LiteralPath $dir -File -Filter $leaf |
                ForEach-Object { $files.Add($_.FullName) }
        }
    }

    return ($files | Sort-Object -Unique)
}

function Is-ExternalLink {
    param([Parameter(Mandatory = $true)][string]$Target)

    return (
        $Target -match '^(?i)https?://' -or
        $Target -match '^(?i)mailto:' -or
        $Target -match '^(?i)tel:'
    )
}

function Normalize-PathLike {
    param([Parameter(Mandatory = $true)][string]$Target)

    # Strip surrounding angle brackets and decode a minimal subset.
    $t = $Target.Trim()
    if ($t.StartsWith('<') -and $t.EndsWith('>')) {
        $t = $t.Substring(1, $t.Length - 2)
    }
    $t = $t -replace '%20', ' '
    return $t
}

$repoRoot = Resolve-RepoRoot
$mdFiles = Get-MarkdownFiles -RepoRoot $repoRoot

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

# Regex for Markdown links and images: [text](target) and ![alt](target)
$linkRegex = '(?<!\\)!?\[[^\]]*\]\(([^\)]+)\)'

foreach ($filePath in $mdFiles) {
    $rel = Resolve-Path -LiteralPath $filePath | ForEach-Object { $_.Path.Substring($repoRoot.Path.Length).TrimStart('\\') }
    $dir = Split-Path -Parent $filePath

    $lines = @(Get-Content -LiteralPath $filePath -Encoding UTF8)

    # Warn if the simple navigation files contain per-heading anchors (fragile across locales)
    if ($filePath -match '[\\/]navigation\.md$' -or $filePath -match '[\\/]i18n[\\/]uk[\\/]navigation\.md$') {
        foreach ($line in $lines) {
            if ($line -match '\]\([^\)]+#') {
                $warnings.Add("${rel}: navigation contains anchored link (fragile): $line")
                break
            }
        }
    }

    foreach ($line in $lines) {
        $matches = [regex]::Matches($line, $linkRegex)
        foreach ($m in $matches) {
            $targetRaw = $m.Groups[1].Value
            $target = Normalize-PathLike -Target $targetRaw

            # Ignore pure anchors and external links
            if ($target.StartsWith('#')) { continue }
            if (Is-ExternalLink -Target $target) { continue }

            # Split off #anchor and ?query for local existence checks
            $noAnchor = $target.Split('#')[0]
            $noQuery = $noAnchor.Split('?')[0]
            if ($noQuery.Trim().Length -eq 0) { continue }

            # Only validate relative repo links (skip absolute like C:\...)
            if ($noQuery -match '^[A-Za-z]:\\') { continue }
            if ($noQuery.StartsWith('/')) {
                # Treat as repo-root relative
                $candidate = Join-Path $repoRoot.Path $noQuery.TrimStart('/')
            } else {
                $candidate = Join-Path $dir $noQuery
            }

            if (-not (Test-Path -LiteralPath $candidate)) {
                $errors.Add("${rel}: broken link target '${noQuery}'")
            } else {
                # If it's an image, encourage assets/images placement (warning only)
                if ($m.Value.StartsWith('![')) {
                    $candidateRel = Resolve-Path -LiteralPath $candidate | ForEach-Object { $_.Path.Substring($repoRoot.Path.Length).TrimStart('\\') }
                    if ($candidateRel -notmatch '^(?i)assets[\\/]images[\\/]') {
                        $warnings.Add("${rel}: image not under assets/images: ${candidateRel}")
                    }
                }
            }
        }
    }
}

Write-Host "Markdown link check complete." -ForegroundColor Cyan
$errorColor = if ($errors.Count -gt 0) { 'Red' } else { 'Green' }
Write-Host ("Errors: {0}" -f $errors.Count) -ForegroundColor $errorColor
Write-Host ("Warnings: {0}" -f $warnings.Count) -ForegroundColor Yellow

if ($warnings.Count -gt 0) {
    Write-Host "" 
    Write-Host "Warnings:" -ForegroundColor Yellow
    $warnings | Select-Object -First 50 | ForEach-Object { Write-Host ("- {0}" -f $_) -ForegroundColor Yellow }
    if ($warnings.Count -gt 50) {
        Write-Host ("(truncated; {0} total warnings)" -f $warnings.Count) -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0) {
    Write-Host "" 
    Write-Host "Errors:" -ForegroundColor Red
    $errors | Select-Object -First 50 | ForEach-Object { Write-Host ("- {0}" -f $_) -ForegroundColor Red }
    if ($errors.Count -gt 50) {
        Write-Host ("(truncated; {0} total errors)" -f $errors.Count) -ForegroundColor Red
    }
    exit 1
}

exit 0
