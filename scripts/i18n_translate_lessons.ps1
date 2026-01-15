param(
  [ValidateSet('uk-to-en-all','uk-to-en-one')]
  [string]$Mode = 'uk-to-en-all',
  [string]$OneFile
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$lessonsEnDir = Join-Path $repoRoot 'course\lessons'
$lessonsUkDir = Join-Path $repoRoot 'i18n\uk\course\lessons'

function Invoke-GoogleTranslate {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [string]$SourceLang = 'uk',
    [string]$TargetLang = 'en'
  )

  if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }

  # Google endpoint is sensitive to very large payloads.
  $maxChars = 3500
  if ($Text.Length -gt $maxChars) {
    $chunks = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $Text.Length) {
      $len = [Math]::Min($maxChars, $Text.Length - $i)
      $chunks.Add($Text.Substring($i, $len))
      $i += $len
    }
    return ($chunks | ForEach-Object { Invoke-GoogleTranslate -Text $_ -SourceLang $SourceLang -TargetLang $TargetLang }) -join ''
  }

  $u = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=' + $SourceLang + '&tl=' + $TargetLang + '&dt=t&q=' + [uri]::EscapeDataString($Text)
  $resp = Invoke-RestMethod -Uri $u -Method Get -TimeoutSec 30
  return $resp[0][0][0]
}

function Contains-Cyrillic {
  param([string]$Text)
  return [regex]::IsMatch($Text, '\p{IsCyrillic}')
}

function Translate-MarkdownLines {
  param(
    [string[]]$Lines,
    [string]$SourceLang = 'uk',
    [string]$TargetLang = 'en'
  )

  $cache = @{}
  $out = New-Object System.Collections.Generic.List[string]

  $inCode = $false
  $batch = New-Object System.Collections.Generic.List[int]
  $batchTexts = New-Object System.Collections.Generic.List[string]
  $splitToken = '@@@__SPLIT__@@@'

  function Flush-Batch {
    if ($batch.Count -eq 0) { return }

    $joined = ($batchTexts -join ("`n$splitToken`n"))
    $translatedJoined = Invoke-GoogleTranslate -Text $joined -SourceLang $SourceLang -TargetLang $TargetLang
    $parts = $translatedJoined -split ("`n$splitToken`n"), -1

    if ($parts.Count -ne $batch.Count) {
      # Fallback: translate line-by-line if splitting didn’t match.
      for ($j = 0; $j -lt $batch.Count; $j++) {
        $idx = $batch[$j]
        $t = $batchTexts[$j]
        $tr = $null
        if ($cache.ContainsKey($t)) { $tr = $cache[$t] } else {
          $tr = Invoke-GoogleTranslate -Text $t -SourceLang $SourceLang -TargetLang $TargetLang
          $cache[$t] = $tr
        }
        $out[$idx] = $tr
      }
    } else {
      for ($j = 0; $j -lt $batch.Count; $j++) {
        $idx = $batch[$j]
        $t = $batchTexts[$j]
        $tr = $parts[$j]
        $cache[$t] = $tr
        $out[$idx] = $tr
      }
    }

    $batch.Clear(); $batchTexts.Clear()
  }

  # Pre-size output
  for ($i = 0; $i -lt $Lines.Count; $i++) { $out.Add($Lines[$i]) }

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    $line = $Lines[$i]

    if ($line -match '^(\s*)(```|~~~)') {
      $inCode = -not $inCode
      continue
    }

    if ($inCode) { continue }

    if (-not (Contains-Cyrillic $line)) { continue }

    # Keep raw HTML blocks with images/layout as-is
    if ($line -match '<\s*img\b' -or $line -match '<\s*div\b' -or $line -match '<\s*/\s*div\s*>' ) {
      continue
    }

    # Translate inner text of <h2 align="center">...</h2>
    if ($line -match '^(\s*<h\d[^>]*>)(.*?)(</h\d>\s*)$') {
      $prefix = $Matches[1]
      $mid = $Matches[2]
      $suffix = $Matches[3]
      $key = "<h>" + $mid
      if ($cache.ContainsKey($key)) {
        $out[$i] = $prefix + $cache[$key] + $suffix
      } else {
        $trMid = Invoke-GoogleTranslate -Text $mid -SourceLang $SourceLang -TargetLang $TargetLang
        $cache[$key] = $trMid
        $out[$i] = $prefix + $trMid + $suffix
      }
      continue
    }

    # Batch normal text lines
    if ($batch.Count -ge 25) { Flush-Batch }
    $batch.Add($i)
    $batchTexts.Add($line)
  }

  Flush-Batch
  return ,$out
}

function Ensure-PrependedLine {
  param(
    [string[]]$Lines,
    [string]$FirstLine,
    [string]$SecondLine = ''
  )

  # If a previous run added a language switcher (or a malformed one), remove it.
  if ($Lines.Count -gt 0) {
    $first = $Lines[0].Trim()
    if ($first -like '**Language:** *' -or $first -match '^\*\*.*\*\*.*\[English\]' -or $first -match 'u\{[0-9A-Fa-f]{4}\}') {
      $Lines = $Lines | Select-Object -Skip 1
      # Also drop a single following blank line if present.
      if ($Lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($Lines[0])) {
        $Lines = $Lines | Select-Object -Skip 1
      }
    }
  }

  if ($Lines.Count -gt 0 -and $Lines[0].Trim() -eq $FirstLine.Trim()) {
    return ,$Lines
  }

  $new = New-Object System.Collections.Generic.List[string]
  $new.Add($FirstLine)
  if (-not [string]::IsNullOrWhiteSpace($SecondLine)) { $new.Add($SecondLine) }
  $new.Add('')
  $new.AddRange($Lines)
  return ,$new
}

function Fix-UkAssetPaths {
  param([string]$Text)
  # Ukrainian lessons are nested deeper under i18n/uk/course/lessons.
  # Normalize any relative path that points to assets/ to exactly '../../../../assets/'.
  return [regex]::Replace($Text, '(?:\.\./)+assets/', '../../../../assets/')
}

$lessonFiles = Get-ChildItem -Path $lessonsEnDir -Filter '*.md' | Sort-Object Name
if ($Mode -eq 'uk-to-en-one') {
  if ([string]::IsNullOrWhiteSpace($OneFile)) { throw 'OneFile is required for uk-to-en-one' }
  $lessonFiles = $lessonFiles | Where-Object { $_.Name -eq $OneFile }
}

foreach ($f in $lessonFiles) {
  Write-Host "Translating EN: $($f.Name)" -ForegroundColor Cyan
  $srcLines = Get-Content -LiteralPath $f.FullName -Encoding UTF8

  $translated = Translate-MarkdownLines -Lines $srcLines -SourceLang 'uk' -TargetLang 'en'

  $ukrLabel = -join @(
    [char]0x0423,[char]0x043A,[char]0x0440,[char]0x0430,[char]0x0457,[char]0x043D,[char]0x0441,[char]0x044C,[char]0x043A,[char]0x0430
  )
  $switcherEn = "**Language:** English | [$ukrLabel](../../i18n/uk/course/lessons/$($f.Name))"
  $translated = Ensure-PrependedLine -Lines $translated -FirstLine $switcherEn

  Set-Content -LiteralPath $f.FullName -Value $translated -Encoding UTF8
}

# Update Ukrainian copies: fix asset paths + add switcher
$ukFiles = Get-ChildItem -Path $lessonsUkDir -Filter '*.md' | Sort-Object Name
foreach ($f in $ukFiles) {
  Write-Host "Fixing UK: $($f.Name)" -ForegroundColor Yellow
  $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  $text = Fix-UkAssetPaths -Text $text
  $lines = $text -split "`r?`n", -1

  $langWord = -join @([char]0x041C,[char]0x043E,[char]0x0432,[char]0x0430)
  $switcherUk = "**${langWord}:** [English](../../../../course/lessons/$($f.Name)) | $ukrLabel"
  $lines = Ensure-PrependedLine -Lines $lines -FirstLine $switcherUk

  Set-Content -LiteralPath $f.FullName -Value $lines -Encoding UTF8
}

Write-Host 'Done.' -ForegroundColor Green
