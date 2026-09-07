param(
    [string]$Orig = '',
    [string]$Trans = (Join-Path $PSScriptRoot '..\book\src')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$trans = [System.IO.Path]::GetFullPath($Trans)

if ([string]::IsNullOrWhiteSpace($Orig)) {
    $candidates = @(
        (Join-Path $PSScriptRoot '..\..\bulletproof-rust-web\book\src'),
        (Join-Path $PSScriptRoot '..\bulletproof-rust-web\book\src'),
        (Join-Path (Get-Location) 'bulletproof-rust-web\book\src')
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath $cand) {
            $Orig = $cand
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Orig) -or (-not (Test-Path -LiteralPath $Orig))) {
    Write-Error "Cannot find upstream bulletproof-rust-web book/src directory.`nPlease provide the path using: ./scripts/verify-translation.ps1 -Orig <path-to-bulletproof-rust-web/book/src>"
    exit 1
}

$orig = [System.IO.Path]::GetFullPath($Orig)
Write-Output "Comparing translation against upstream:"
Write-Output "  Upstream:    $orig"
Write-Output "  Translation: $trans"

function Read-Normalized($path) {
    return ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)).Replace("`r`n", "`n")
}

function Get-CodeBlocks($path) {
    $content = Read-Normalized $path
    $rx = [regex]'```(?s:.*?)```'
    return @($rx.Matches($content) | ForEach-Object { $_.Value })
}

function Get-Headings($path) {
    $content = Read-Normalized $path
    $rx = [regex]'(?m)^#{1,6} .*$'
    return @($rx.Matches($content) | ForEach-Object { $_.Value })
}

function Get-RefLinks($path) {
    $content = Read-Normalized $path
    $rx = [regex]'(?m)^\[[^\]]+\]:\s+\S+.*$'
    return @($rx.Matches($content) | ForEach-Object { $_.Value -replace '\s+$','' })
}

function Get-InlineLinkTargets($path) {
    $content = Read-Normalized $path
    $rx = [regex]'\[[^\]]*\]\(([^)]+)\)'
    return @($rx.Matches($content) | ForEach-Object { $_.Groups[1].Value -replace '\s+$','' })
}

function Normalize-LinkTarget($url) {
    if ([string]::IsNullOrWhiteSpace($url)) {
        return ''
    }
    $trimmed = $url.Trim()
    # In-page anchor link (anchors are translated to Thai slugs and checked by check-links.ps1)
    if ($trimmed.StartsWith('#')) {
        return '#anchor'
    }
    # File link with in-page anchor (e.g. database.md#connection-pool-setup vs database.md#การตั้งค่าพูลการเชื่อมต่อ)
    if ($trimmed -match '^([^#]+)#(.+)$') {
        return $Matches[1]
    }
    return $trimmed
}

# Documented deviations from upstream, enforced on the translation side only.
# Upstream defect fixed in the Thai edition:
#   middleware.md links to ./putting-it-all-together.md, but the actual chapter
#   file is putting-it-together.md - the link 404s on the upstream site. We fix
#   the target so every link in the built book resolves (check-links gate).
$UpstreamFixMap = @{
    './putting-it-all-together.md' = './putting-it-together.md'
}

$origFiles = Get-ChildItem -Recurse -File $orig -Filter *.md
$fail = 0
$total = 0

foreach ($f in $origFiles) {
    $rel = $f.FullName.Substring($orig.Length + 1)
    $tPath = Join-Path $trans $rel
    $total++
    if (-not (Test-Path -LiteralPath $tPath)) {
        Write-Output "[FAIL] $rel : missing translated file"
        $fail++
        continue
    }

    $oc = Get-CodeBlocks $f.FullName
    $tc = Get-CodeBlocks $tPath
    if ($oc.Count -ne $tc.Count) {
        Write-Output "[FAIL] $rel : code block count differs (orig=$($oc.Count) trans=$($tc.Count))"
        $fail++
    } else {
        for ($i = 0; $i -lt $oc.Count; $i++) {
            if ($oc[$i] -cne $tc[$i]) {
                Write-Output "[FAIL] $rel : code block #$($i+1) differs"
                $fail++
            }
        }
    }

    $oh = Get-Headings $f.FullName
    $th = Get-Headings $tPath
    if ($oh.Count -ne $th.Count) {
        Write-Output "[FAIL] $rel : heading count differs (orig=$($oh.Count) trans=$($th.Count))"
        $fail++
    } else {
        for ($i = 0; $i -lt $oh.Count; $i++) {
            $ol = ($oh[$i] -split ' ')[0]
            $tl = ($th[$i] -split ' ')[0]
            if ($ol -cne $tl) {
                Write-Output "[FAIL] $rel : heading #$($i+1) level differs (orig='$($oh[$i])' trans='$($th[$i])')"
                $fail++
            }
        }
    }

    $or = Get-RefLinks $f.FullName
    $tr = Get-RefLinks $tPath
    if ($or.Count -ne $tr.Count) {
        Write-Output "[FAIL] $rel : ref-link count differs (orig=$($or.Count) trans=$($tr.Count))"
        $fail++
    } else {
        for ($i = 0; $i -lt $or.Count; $i++) {
            $ourl = Normalize-LinkTarget (($or[$i] -split ':\s*',2)[1])
            $turl = Normalize-LinkTarget (($tr[$i] -split ':\s*',2)[1])
            if ($ourl -cne $turl) {
                Write-Output "[FAIL] $rel : ref-link #$($i+1) url differs (orig='$ourl' trans='$turl')"
                $fail++
            }
        }
    }

    $oi = @(Get-InlineLinkTargets $f.FullName | ForEach-Object { $u = Normalize-LinkTarget $_; if ($UpstreamFixMap.ContainsKey($_)) { $u = $UpstreamFixMap[$_] }; $u })
    $ti = @(Get-InlineLinkTargets $tPath | ForEach-Object { Normalize-LinkTarget $_ })
    $os = $oi | Sort-Object -Unique
    $ts = $ti | Sort-Object -Unique
    $missing = @($os | Where-Object { $_ -notin $ts })
    $extra = @($ts | Where-Object { $_ -notin $os })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        Write-Output "[FAIL] $rel : inline link targets differ (missing=[$($missing -join ', ')] extra=[$($extra -join ', ')])"
        $fail++
    }
}

Write-Output "---"
Write-Output "Checked $total files, $fail problem(s)"
if ($fail -eq 0) { Write-Output "ALL OK: code blocks, headings, links match 100%" }
exit ($fail -gt 0)