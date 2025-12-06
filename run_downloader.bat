@echo off
setlocal
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "%~dp0download_gmod_workshop.ps1" %*
endlocal
pause
