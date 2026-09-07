param(
    [string]$BookDir = (Join-Path $PSScriptRoot '..\book\book')
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$book = [System.IO.Path]::GetFullPath($BookDir)

$files = Get-ChildItem -Recurse -File $book -Filter *.html
$broken = @()
$total = 0

foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName)
    $ids = @{}
    foreach ($m in [regex]::Matches($content, 'id="([^"]+)"')) { $ids[$m.Groups[1].Value] = $true }

    $rel = $f.FullName.Substring($book.Length + 1).Replace('\','/')
    $dir = Split-Path $rel -Parent
    foreach ($m in [regex]::Matches($content, 'href="([^"]*)"')) {
        $href = $m.Groups[1].Value
        if ($href -like 'http*' -or $href -like 'javascript*' -or $href -eq '') { continue }
        if ($href.StartsWith('#')) {
            $total++
            $target = $href.Substring(1)
            if (-not $ids.ContainsKey($target)) {
                $broken += "$rel -> #$target (id not found)"
            }
        } elseif ($href -like '*.html*' -or $href -like '*print.html*') {
            $page = ($href -split '[?#]')[0]
            $resolved = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $f.FullName) ($page -replace '/', '\')))
            if (-not (Test-Path -LiteralPath $resolved)) {
                $broken += "$rel -> $href (file missing)"
                continue
            }
            if ($href -match '#(.+)$') {
                $total++
                $target = $Matches[1]
                $pContent = [System.IO.File]::ReadAllText($resolved)
                if ($pContent -notmatch 'id="' + [regex]::Escape($target) + '"') {
                    $broken += "$rel -> $href (anchor not found in target)"
                }
            }
        }
    }
}

Write-Output "Checked $total anchor links"
if ($broken.Count -eq 0) { Write-Output "ALL ANCHOR LINKS OK" }
else { $broken | ForEach-Object { Write-Output "[BROKEN] $_" } }