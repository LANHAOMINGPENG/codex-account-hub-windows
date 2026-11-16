@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Codex-Multi-Account-Manager.ps1"
if errorlevel 1 (
  echo.
  echo Codex Account Hub failed to start. See the error above.
  pause
)
endlocal
