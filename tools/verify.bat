@echo off
rem Windows wrapper for tools/verify.sh (this machine has no bash; see AUDIT.md item 4).
rem Logic lives in verify.ps1. Set GODOT env var to override the Godot path.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify.ps1" %*
exit /b %ERRORLEVEL%
