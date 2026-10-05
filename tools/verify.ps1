# Windows wrapper for tools/verify.sh - same stages, no bash/md5sum needed.
# Why it exists: the dev machine has no bash (git is bundled inside GitHub
# Desktop) and PowerShell 5.1 garbles non-ASCII script literals; see
# AUDIT.md item 4. That is why THIS FILE IS ASCII-ONLY and the GDScript
# summary line is parsed NUMERICALLY instead of matching Russian text.
# Stages: smoke (main.tscn) -> verify.gd playability sweep -> md2html --check
# (if python present) -> MD5 snapshot of ALL .cfg in the user data folder.
# Usage: tools\verify.bat   (env var GODOT overrides the Godot path)

$ErrorActionPreference = 'Continue'
$proj  = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT) { $env:GODOT } else { 'C:\Users\Admin\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path $godot)) { Write-Output "Godot not found: $godot (set GODOT=...)"; exit 2 }
$ud = Join-Path $env:APPDATA 'Godot\app_userdata\Maze'
$rc = 0
$out  = [IO.Path]::GetTempFileName()
$errf = [IO.Path]::GetTempFileName()

function Snap-Cfg {
    if (-not (Test-Path $ud)) { return @() }
    Get-ChildItem $ud -Recurse -Filter *.cfg | ForEach-Object {
        $_.FullName.Substring($ud.Length + 1) + ' ' + (Get-FileHash $_.FullName -Algorithm MD5).Hash
    } | Sort-Object
}
function Run-Godot {
    param([string[]]$Args2)
    Remove-Item $out, $errf -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $godot -ArgumentList $Args2 -WorkingDirectory $proj `
         -RedirectStandardOutput $out -RedirectStandardError $errf -NoNewWindow -Wait -PassThru
    return @(Get-Content $out -Encoding UTF8 -ErrorAction SilentlyContinue) +
           @(Get-Content $errf -Encoding UTF8 -ErrorAction SilentlyContinue)
}

$before = @(Snap-Cfg)

Write-Output "== smoke =="
$lines = Run-Godot @('--headless', '--path', '.', 'res://main.tscn', '--quit-after', '90')
$bad = $lines | Where-Object { $_ -match 'error|SCRIPT|parse|invalid|nonexistent' -and $_ -notmatch 'resources still|audio' }
if ($bad) { $bad | ForEach-Object { Write-Output $_ }; $rc = 1 } else { Write-Output 'clean' }

Write-Output "== playability =="
$vlines = Run-Godot @('--headless', '--path', '.', '-s', 'res://tools/verify.gd')
$vbad = $vlines | Where-Object { $_ -match '^FAIL|^VERIFY' }
if ($vbad) { $vbad | ForEach-Object { Write-Output $_ } } else { Write-Output 'verify.gd did not run, tail:'; $vlines | Select-Object -Last 5 | ForEach-Object { Write-Output $_ }; $rc = 1 }
# summary line: "VERIFY: <checked N>, <failures-word> M" - require M == 0
$vfail = $null
foreach ($ln in $vlines) { if ($ln -match '^VERIFY:.*\s(\d+)\s*$') { $vfail = [int]$Matches[1] } }
if ($null -eq $vfail) { Write-Output 'verify: summary line not parsed'; $rc = 1 }
elseif ($vfail -ne 0) { Write-Output ('verify: failures = ' + $vfail); $rc = 1 }
if ($vlines -match 'invalid entry') { Write-Output 'SPAWN-SAFETY fired: entry was invalid'; $rc = 1 }

Write-Output "== docs =="
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py -and $py.Source -notmatch 'WindowsApps') {
    & python (Join-Path $proj 'tools\md2html.py') --check
    if ($LASTEXITCODE -ne 0) { Write-Output 'run: python tools/md2html.py'; $rc = 1 }
} else { Write-Output 'python not found - skip (see AUDIT.md phase 3)' }

Write-Output "== saves =="
$after = @(Snap-Cfg)
$cmp = Compare-Object -ReferenceObject $before -DifferenceObject $after
if (-not $cmp) { Write-Output 'unchanged' } else { Write-Output 'CHANGED:'; $cmp | ForEach-Object { Write-Output $_.InputObject }; $rc = 1 }

Remove-Item $out, $errf -ErrorAction SilentlyContinue
if ($rc -eq 0) { Write-Output 'ALL OK' } else { Write-Output 'PROBLEMS FOUND' }
exit $rc
