[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LessonsDir = "course/lessons",

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "navigation_detailed.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-GitHubSlug {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][hashtable]$Seen
    )

    $s = $Text

    # Normalize whitespace and decode common HTML entities.
    try {
        $s = [System.Net.WebUtility]::HtmlDecode($s)
    } catch {
        # If HtmlDecode isn't available, continue with raw text.
    }

    $s = $s.Trim().ToLowerInvariant()

    # GitHub-style-ish slugging (close enough for plain English headings)
    # - remove punctuation
    # - keep letters/digits/spaces/hyphens
    # - spaces -> hyphen
    $s = [regex]::Replace($s, "[^a-z0-9\s-]", "")
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

    foreach ($line in Get-Content -LiteralPath $FilePath -Encoding UTF8) {
        if ($line -match '^```') {
            $inCodeFence = -not $inCodeFence
            continue
        }

        if ($inCodeFence) {
            continue
        }

        # HTML headings like: <h2 align="center">Title</h2>
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

        # Markdown headings like: ## Title
        $mdMatch = [regex]::Match($line, '^(#{1,6})\s+(.+?)\s*$', [System.Text.RegularExpressions.RegexOptions]::None)
        if ($mdMatch.Success) {
            $level = $mdMatch.Groups[1].Value.Length
            $text = $mdMatch.Groups[2].Value.Trim()

            # Ignore the language switcher line if someone used a heading
            if ($text -match '^(Language|Мова)\s*:\s*') {
                continue
            }

            if ($text) {
                $headings.Add([pscustomobject]@{ Level = $level; Text = $text })
            }
            continue
        }
    }

    return $headings
}

$lessonIndex = @(
    @{ File = "01_sql_vstup.md"; Title = "Lesson 1: SQL introduction and relational databases" },
    @{ File = "02_bazovi_funkcii_sql.md"; Title = "Lesson 2: Logical operators and aggregation" },
    @{ File = "03_stvorennia_tablets_struktur.md"; Title = "Lesson 3: Data structures (DDL, CTE, UNION)" },
    @{ File = "04_robota_z_danymy_dml.md"; Title = "Lesson 4: Data manipulation (DML and JOIN)" },
    @{ File = "05_ochystka_danyh_riadkovi_funkcii.md"; Title = "Lesson 5: Data cleaning and string functions" },
    @{ File = "06_data_chas_vikonni_funkcii.md"; Title = "Lesson 6: Dates/time, JSON, and window functions" },
    @{ File = "07_advanced_query_patterns.md"; Title = "Lesson 7: Advanced query patterns" },
    @{ File = "07b_window_functions_deep_dive.md"; Title = "Lesson 7B: Window functions deep dive" },
    @{ File = "08_transactions_concurrency.md"; Title = "Lesson 8: Transactions and concurrency" },
    @{ File = "09_stored_procedures_error_handling.md"; Title = "Lesson 9: Stored procedures and error handling" },
    @{ File = "10_udf_tvf_and_views.md"; Title = "Lesson 10: Views, UDFs, and TVFs" },
    @{ File = "11_indexing_and_sargability.md"; Title = "Lesson 11: Indexing and SARGability" },
    @{ File = "12_etl_patterns_staging_upsert.md"; Title = "Lesson 12: ETL patterns (staging, upsert, batching)" },
    @{ File = "13_backup_restore_basics.md"; Title = "Lesson 13: Backup/restore basics" },
    @{ File = "14_security_permissions.md"; Title = "Lesson 14: Security and permissions" },
    @{ File = "15_advanced_analytics_sql.md"; Title = "Lesson 15: Advanced analytics SQL" },
    @{ File = "16_monitoring_and_troubleshooting.md"; Title = "Lesson 16: Monitoring and troubleshooting" },
    @{ File = "17_table_expressions_lab_pack.md"; Title = "Lesson 17: Table expressions lab pack (derived tables, CTEs, APPLY)" },
    @{ File = "x_spatial_types_and_indexing.md"; Title = "Bonus: Spatial types and indexing" }
)

$lines = New-Object System.Collections.Generic.List[string]
$ukLabel = -join @(
    [char]0x0423,[char]0x043A,[char]0x0440,[char]0x0430,[char]0x0457,
    [char]0x043D,[char]0x0441,[char]0x044C,[char]0x043A,[char]0x0430
)

$lines.Add(("**Language:** English | [{0}](i18n/uk/navigation_detailed.md)" -f $ukLabel))
$lines.Add("")
$lines.Add("# Navigation (detailed heading index)")
$lines.Add("")
$lines.Add("This page lists the lesson headings and links directly to them.")
$lines.Add("")
$lines.Add("- Simple lesson list: [navigation.md](navigation.md)")
$lines.Add("- Recommended order: [LEARNING_PATH.md](LEARNING_PATH.md)")
$lines.Add("")

foreach ($lesson in $lessonIndex) {
    $lessonPath = Join-Path -Path $LessonsDir -ChildPath $lesson.File
    if (-not (Test-Path -LiteralPath $lessonPath)) {
        throw "Lesson file not found: $lessonPath"
    }

    $lessonHref = $lessonPath.Replace('\\', '/').Replace('\', '/')
    $lines.Add(("## [{0}]({1})" -f $lesson.Title, $lessonHref))

    $headings = Get-HeadingsFromMarkdown -FilePath $lessonPath
    $seen = @{}

    foreach ($h in $headings) {
        # Keep the output readable: only index h2/h3 (and md ##/###) by default.
        if ($h.Level -lt 2 -or $h.Level -gt 3) {
            continue
        }

        $slug = ConvertTo-GitHubSlug -Text $h.Text -Seen $seen
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
