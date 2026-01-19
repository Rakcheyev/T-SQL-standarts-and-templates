[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$EnLessonsDir = "course/lessons",

    [Parameter(Mandatory = $false)]
    [string]$UkLessonsDir = "i18n/uk/course/lessons"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$enRoot = Join-Path $repoRoot $EnLessonsDir
$ukRoot = Join-Path $repoRoot $UkLessonsDir

# Avoid encoding issues with Cyrillic literals in some PowerShell/console setups.
$uaMova = -join @([char]0x041C,[char]0x043E,[char]0x0432,[char]0x0430)
$uaVstup = -join @([char]0x0412,[char]0x0441,[char]0x0442,[char]0x0443,[char]0x043F)
$uaPidsumok = -join @(
    [char]0x041F,[char]0x0456,[char]0x0434,[char]0x0441,[char]0x0443,[char]0x043C,[char]0x043E,[char]0x043A
)
$uaVysnovok = -join @(
    [char]0x0412,[char]0x0438,[char]0x0441,[char]0x043D,[char]0x043E,[char]0x0432,[char]0x043E,[char]0x043A
)

function Get-NextNonEmptyLine {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][int]$StartIndex
    )

    for ($i = $StartIndex; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim().Length -gt 0) {
            return [pscustomobject]@{ Index = $i; Line = $Lines[$i] }
        }
    }

    return $null
}

function Find-FirstIndex {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) {
            return $i
        }
    }

    return -1
}

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $enRoot)) {
    throw "EN lessons dir not found: $enRoot"
}
if (-not (Test-Path -LiteralPath $ukRoot)) {
    throw "UK lessons dir not found: $ukRoot"
}

$enFiles = Get-ChildItem -LiteralPath $enRoot -Filter "*.md" -File | Sort-Object Name
$ukFiles = Get-ChildItem -LiteralPath $ukRoot -Filter "*.md" -File | Sort-Object Name

$enByName = @{}
foreach ($f in $enFiles) { $enByName[$f.Name] = $f.FullName }

$ukByName = @{}
foreach ($f in $ukFiles) { $ukByName[$f.Name] = $f.FullName }

# Pairing checks
foreach ($name in $enByName.Keys | Sort-Object) {
    if (-not $ukByName.ContainsKey($name)) {
        $errors.Add("Missing Ukrainian mirror for EN lesson: $name")
    }
}
foreach ($name in $ukByName.Keys | Sort-Object) {
    if (-not $enByName.ContainsKey($name)) {
        $warnings.Add("Extra Ukrainian lesson without EN counterpart: $name")
    }
}

function Check-LessonFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][ValidateSet('en','uk')][string]$Locale
    )

    $lines = @(Get-Content -LiteralPath $FilePath -Encoding UTF8)
    $fileName = Split-Path -Leaf $FilePath

    $isNewLesson = $fileName -match '^(07b|07|08|09|1[0-4]|x)_' 

    if ($lines.Count -eq 0) {
        $script:errors.Add("${fileName}: file is empty")
        return
    }

    # Language switcher near the top
    $top = $lines | Select-Object -First 6
    $langPattern = if ($Locale -eq 'en') { '^\*\*Language:\*\*' } else { ('^\*\*' + $uaMova + ':\*\*') }
    if (-not ($top -match $langPattern)) {
        $script:errors.Add("${fileName}: missing language switcher near top ($langPattern)")
    }

    # Title heading (we expect <h2 ...>...</h2>, but accept a Markdown H2 as fallback)
    $titleIndex = Find-FirstIndex -Lines $lines -Pattern '^\s*<h2\b'
    if ($titleIndex -lt 0) {
        $titleIndex = Find-FirstIndex -Lines $lines -Pattern '^##\s+'
    }
    if ($titleIndex -lt 0) {
        $script:errors.Add("${fileName}: missing lesson title heading (<h2> or ##)")
        return
    }

    if ($isNewLesson) {
        # Intro marker must be the next non-empty line after the title
        $expectedIntro = if ($Locale -eq 'en') { '^\*Intro:\*' } else { ('^\*' + $uaVstup + ':\*') }
        $next = Get-NextNonEmptyLine -Lines $lines -StartIndex ($titleIndex + 1)
        if ($null -eq $next) {
            $script:errors.Add("${fileName}: file ends right after the title heading")
        } elseif ($next.Line -notmatch $expectedIntro) {
            $script:errors.Add("${fileName}: intro marker is not immediately after title (expected: $expectedIntro)")
        }

        # Summary section + conclusion marker inside (or after) it
        $summaryPattern = if ($Locale -eq 'en') { '^##\s+Summary' } else { ('^##\s+' + $uaPidsumok) }
        $summaryIndex = Find-FirstIndex -Lines $lines -Pattern $summaryPattern
        if ($summaryIndex -lt 0) {
            $script:errors.Add("${fileName}: missing summary heading (pattern: $summaryPattern)")
            return
        }

        # Encourage at least one Microsoft Learn link in Summary/Pidsumok (non-blocking: warning).
        $hasLearnLink = $false
        for ($i = $summaryIndex; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'learn\.microsoft\.com') {
                $hasLearnLink = $true
                break
            }
        }
        if (-not $hasLearnLink) {
            $script:warnings.Add("${fileName}: no learn.microsoft.com links found after Summary/Pidsumok")
        }

        $conclusionPattern = if ($Locale -eq 'en') { '^\*Conclusion:\*' } else { ('^\*' + $uaVysnovok + ':\*') }
        $conclusionIndex = Find-FirstIndex -Lines $lines -Pattern $conclusionPattern
        if ($conclusionIndex -lt 0) {
            $script:errors.Add("${fileName}: missing conclusion marker (pattern: $conclusionPattern)")
        } elseif ($conclusionIndex -lt $summaryIndex) {
            $script:errors.Add("${fileName}: conclusion marker appears before Summary/Pidsumok")
        }
    }
}

foreach ($name in $enByName.Keys | Sort-Object) {
    Check-LessonFile -FilePath $enByName[$name] -Locale 'en'
}

foreach ($name in $ukByName.Keys | Sort-Object) {
    Check-LessonFile -FilePath $ukByName[$name] -Locale 'uk'
}

Write-Host "Sanity check complete." -ForegroundColor Cyan
$errorColor = if ($errors.Count -gt 0) { 'Red' } else { 'Green' }
Write-Host ("Errors: {0}" -f $errors.Count) -ForegroundColor $errorColor
Write-Host ("Warnings: {0}" -f $warnings.Count) -ForegroundColor Yellow

if ($warnings.Count -gt 0) {
    Write-Host "" 
    Write-Host "Warnings:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host ("- {0}" -f $_) -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host "" 
    Write-Host "Errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host ("- {0}" -f $_) -ForegroundColor Red }
    exit 1
}

exit 0
