@echo off
rem Windows wrapper for tools/bot.gd - the gameplay bot (3 play styles).
rem Logic lives in bot.ps1. Env overrides: GODOT, BOT_LEVELS, BOT_MODES, BOT_DIFF.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot.ps1" %*
exit /b %ERRORLEVEL%
