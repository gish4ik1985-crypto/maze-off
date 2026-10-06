# Windows wrapper for tools/bot.gd (gameplay bot, GAMEDESIGN section 94).
# Runs the bot headless, saves the full log to %TEMP%, prints a summary:
# results by style, outcome counts, engine errors. MD5 of ALL .cfg in the
# user folder is snapshotted before/after (the bot sets test_mode every
# frame, so saves must not change).
# Usage: tools\bot.bat   (env: GODOT, BOT_LEVELS, BOT_MODES, BOT_DIFF)

$ErrorActionPreference = 'Continue'
$proj  = Split-Path -Parent $PSScriptRoot
$godot = if ($env:GODOT) { $env:GODOT } else { 'C:\Users\Admin\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path $godot)) { Write-Output "Godot not found: $godot (set GODOT=...)"; exit 2 }
$ud = Join-Path $env:APPDATA 'Godot\app_userdata\Maze'
$out  = [IO.Path]::GetTempFileName()
$errf = [IO.Path]::GetTempFileName()

function Snap-Cfg {
    if (-not (Test-Path $ud)) { return @() }
    Get-ChildItem $ud -Recurse -Filter *.cfg | ForEach-Object {
        $_.FullName.Substring($ud.Length + 1) + ' ' + (Get-FileHash $_.FullName -Algorithm MD5).Hash
    } | Sort-Object
}
$before = @(Snap-Cfg)

$modesLabel = 'speedrun,pro,noob'
if ($env:BOT_MODES) { $modesLabel = $env:BOT_MODES }
Write-Output ('== bot: ' + $modesLabel + ' ==')

# Another running Godot instance (editor/game) shares user:// and writes its
# own saves - the "saves changed" check below would be a false alarm then.
$others = Get-Process -Name 'Godot*', 'Godot_v*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -ne $PID }
if ($others) { Write-Output 'NOTE: another Godot process is running - save hash check may be a false alarm' }
$p = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', '.', '-s', 'res://tools/bot.gd') `
     -WorkingDirectory $proj -RedirectStandardOutput $out -RedirectStandardError $errf -NoNewWindow -Wait -PassThru
$lines = @(Get-Content $out -Encoding UTF8 -ErrorAction SilentlyContinue) +
         @(Get-Content $errf -Encoding UTF8 -ErrorAction SilentlyContinue)

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $env:TEMP ("maze_bot_{0}.log" -f $stamp)
$lines | Out-File -FilePath $log -Encoding utf8
Write-Output ("log: " + $log)

# Results table + summary lines from the bot itself.
$results = $lines | Where-Object { $_ -like 'BOTRESULT|*' }
$results | ForEach-Object { Write-Output $_ }
$lines | Where-Object { $_ -match '^BOT:' -or $_ -match '^BOT DONE' -or $_ -match '^BOT FAILED' } |
    ForEach-Object { Write-Output $_ }

# Engine errors in the log = bugs the bot tripped over. SPAWN-SAFETY warnings
# are EXPECTED on level 50: the arena door drops the player outside the arena
# bounds and the game's own safety net snaps arrival (GAMEDESIGN §37) - that is
# the net working, not a bug.
$errors = $lines | Where-Object { $_ -match 'ERROR|SCRIPT ERROR|Parse Error|invalid' -and $_ -notmatch 'resources still|audio|SPAWN-SAFETY' }
if ($errors) {
    Write-Output '--- engine errors seen during runs ---'
    $errors | Select-Object -First 20 | ForEach-Object { Write-Output $_ }
}

Write-Output '== saves =='
$after = @(Snap-Cfg)
$cmp = Compare-Object -ReferenceObject $before -DifferenceObject $after
if (-not $cmp) { Write-Output 'unchanged' } else { Write-Output 'CHANGED:'; $cmp | ForEach-Object { Write-Output $_.InputObject } }

$expected = ($lines | Where-Object { $_ -match '^BOT:' }).Count
if ($results.Count -eq 0 -or $expected -eq 0 -or $errors) { Write-Output 'BOT WRAPPER: PROBLEMS'; exit 1 }
Write-Output 'BOT WRAPPER: ALL OK'
exit 0
