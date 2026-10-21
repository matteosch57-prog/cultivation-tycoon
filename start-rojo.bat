@echo off
REM Double-click me. Bypasses ExecutionPolicy for this one run only.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-rojo.ps1" %*
