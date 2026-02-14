# fix_encoding_and_push.ps1
# Run from repository root (where .git is).
$encUtf = [System.Text.Encoding]::UTF8
$enc1252 = [System.Text.Encoding]::GetEncoding(1252)
$files = @('masterly-html/demo-4/dark.html','index.html')

foreach ($f in $files) {
  if (-not (Test-Path $f)) { Write-Host "Skipping missing: $f"; continue }
  $path = (Resolve-Path $f).Path
  Write-Host "---- Processing $f ----"
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $utf8str = $encUtf.GetString($bytes)
  $cp1252str = $enc1252.GetString($bytes)

  Write-Host "Before (snippet):"
  $utf8str | Select-String -Pattern "designer" -Context 0,2 | ForEach-Object { Write-Host $_.Line }

  $useCpFix = ($utf8str -match 'Ã|â') -and -not ($cp1252str -match 'Ã|â')
  if ($useCpFix) {
    $out = $cp1252str
    Write-Host "Chose CP1252->UTF8 reinterpretation for $f"
  } else {
    # targeted safe replacements fallback
    $out = $utf8str `
      -replace 'â€™','’' `
      -replace 'â€\u009d','”' `
      -replace 'â€œ','“' `
      -replace 'â€“','–' `
      -replace 'â€”','—' `
      -replace 'â€¦','…' `
      -replace 'Ã©','é' `
      -replace 'Ã¨','è' `
      -replace 'Ã´','ô' `
      -replace 'Ã¹','ù' `
      -replace 'Ã¢','â' `
      -replace 'Ã§','ç' `
      -replace 'Ã±','ñ' `
      -replace 'Â','' `
      -replace 'â€','"'
    if ($out -ne $utf8str) { Write-Host "Applied targeted replacements for $f" } else { Write-Host "No recognizable mojibake patterns found for $f; leaving content as-is" }
  }

  # ensure meta charset present
  if ($out -notmatch '(?i)<meta\s+charset') {
    $out = $out -replace '(?i)(<head\b[^>]*>)',"$1`n    <meta charset=`"utf-8`">"
    Write-Host "Inserted <meta charset=`"utf-8`"> into $f"
  }

  [System.IO.File]::WriteAllText($path, $out, $encUtf)
  Write-Host "Saved $f as UTF-8 (no BOM)"

  Write-Host "After (snippet):"
  $out | Select-String -Pattern "designer" -Context 0,2 | ForEach-Object { Write-Host $_.Line }
  Write-Host ""
}

# Commit & push
git switch main
git add masterly-html/demo-4/dark.html index.html
git commit -m "Repair encoding: fix mojibake and save as UTF-8" || Write-Host "Nothing to commit"
git pull --rebase --autostash origin main
git push origin main

Write-Host "Done. Wait ~30s for Pages to rebuild, then hard-refresh the live site (Ctrl+Shift+R) or check Incognito."
