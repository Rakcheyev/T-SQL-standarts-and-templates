[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LessonsDir = "i18n/uk/course/lessons",

    [Parameter(Mandatory = $false)]
    [string]$LinkPrefix = "course/lessons",

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "i18n/uk/navigation_detailed.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-GitHubSlugUnicode {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$Seen
    )

    $s = $Text

    try {
        $s = [System.Net.WebUtility]::HtmlDecode($s)
    } catch {
        # ignore
    }

    $s = $s.Trim().ToLowerInvariant()

    # Keep Unicode letters/numbers, whitespace, and hyphen. Remove punctuation.
    $s = [regex]::Replace($s, "[^\p{L}\p{Nd}\s-]", "")
    $s = [regex]::Replace($s, "\s+", "-")
    $s = [regex]::Replace($s, "-+", "-")
    $s = $s.Trim('-')

    if (-not $s) {
        $s = "section"
    }

    if ($Seen.ContainsKey($s)) {
        $Seen[$s] = [int]$Seen[$s] + 1
        return "{0}-{1}" -f $s, ($Seen[$s] - 1)
    }

    $Seen[$s] = 1
    return $s
}

function Get-HeadingsFromMarkdown {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $inCodeFence = $false
    $headings = New-Object System.Collections.Generic.List[object]

    foreach ($line in Get-Content -LiteralPath $FilePath) {
        if ($line -match '^```') {
            $inCodeFence = -not $inCodeFence
            continue
        }

        if ($inCodeFence) {
            continue
        }

        $htmlMatch = [regex]::Match($line, '^\s*<h([1-6])[^>]*>(.*?)</h\1>\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($htmlMatch.Success) {
            $level = [int]$htmlMatch.Groups[1].Value
            $text = $htmlMatch.Groups[2].Value
            $text = [regex]::Replace($text, '<[^>]+>', '')
            $text = $text.Trim()

            if ($text) {
                $headings.Add([pscustomobject]@{ Level = $level; Text = $text })
            }
            continue
        }

        $mdMatch = [regex]::Match($line, '^(#{1,6})\s+(.+?)\s*$', [System.Text.RegularExpressions.RegexOptions]::None)
        if ($mdMatch.Success) {
            $level = $mdMatch.Groups[1].Value.Length
            $text = $mdMatch.Groups[2].Value.Trim()

            if ($text) {
                $headings.Add([pscustomobject]@{ Level = $level; Text = $text })
            }
            continue
        }
    }

    return $headings
}

$lessonFiles = @(
    "lesson_1_sql_vstup.md",
    "lesson_2_bazovi_funkcii_sql.md",
    "lesson_3_stvorennia_tablets_struktur.md",
    "lesson_4_robota_z_danymy_dml.md",
    "lesson_5_ochystka_danyh_riadkovi_funkcii.md",
    "lesson_6_data_chas_vikonni_funkcii.md"
)

$lines = New-Object System.Collections.Generic.List[string]

# Avoid encoding issues with Cyrillic literals in some PowerShell/console setups.
$uaLanguage = -join @([char]0x0423,[char]0x043A,[char]0x0440,[char]0x0430,[char]0x0457,[char]0x043D,[char]0x0441,[char]0x044C,[char]0x043A,[char]0x0430)
$uaWordMova = -join @([char]0x041C,[char]0x043E,[char]0x0432,[char]0x0430)
$uaWordUrok = -join @([char]0x0423,[char]0x0440,[char]0x043E,[char]0x043A)

$lines.Add(("**{0}:** [English](../../navigation_detailed.md) | {1}" -f $uaWordMova, $uaLanguage))
$lines.Add("")
$lines.Add("# Navigation (detailed heading index)")
$lines.Add("")
$lines.Add("This page lists Ukrainian lesson headings and links directly to them.")
$lines.Add("")
$lines.Add("- Simple index: [navigation.md](navigation.md)")
$lines.Add("- Recommended order: [LEARNING_PATH.md](LEARNING_PATH.md)")
$lines.Add("")

for ($i = 0; $i -lt $lessonFiles.Count; $i++) {
    $fileName = $lessonFiles[$i]
    $lessonFsPath = Join-Path -Path $LessonsDir -ChildPath $fileName
    if (-not (Test-Path -LiteralPath $lessonFsPath)) {
        throw "Lesson file not found: $lessonFsPath"
    }

    $headings = Get-HeadingsFromMarkdown -FilePath $lessonFsPath
    $firstHeading = $headings | Where-Object { $_.Level -ge 2 } | Select-Object -First 1
    $titleText = if ($null -ne $firstHeading) { [string]$firstHeading.Text } else { $fileName }

    $lessonHref = ("{0}/{1}" -f $LinkPrefix.TrimEnd('/'), $fileName).Replace('\\', '/').Replace('\', '/')
    $lessonTitle = ("{0} {1}: {2}" -f $uaWordUrok, ($i + 1), $titleText)
    $lines.Add(("## [{0}]({1})" -f $lessonTitle, $lessonHref))

    $seen = @{}

    foreach ($h in $headings) {
        if ($h.Level -lt 2 -or $h.Level -gt 3) {
            continue
        }

        $slug = ConvertTo-GitHubSlugUnicode -Text $h.Text -Seen $seen
        $indent = "  "
        if ($h.Level -eq 3) {
            $indent = "    "
        }

        $safeText = $h.Text.Replace('[', '\\[').Replace(']', '\\]')
        $lines.Add(("{0}- [{1}]({2}#{3})" -f $indent, $safeText, $lessonHref, $slug))
    }

    $lines.Add("")
}

$lines | Set-Content -LiteralPath $OutputFile -Encoding UTF8
Write-Host "Wrote $OutputFile" -ForegroundColor Green
