@echo off
setlocal
cd /d "%~dp0"
rem ============================================================
rem  FF7 Rebirth - DLSS 5 (RenodX) - uninstaller (standalone)
rem
rem  NOTE: after running the installer you normally do NOT need
rem  this file - the installer creates its own uninstall-dlss5.bat
rem  in the game folder with the correct GitHub URL already set.
rem  Use this standalone copy only if you want to remove the mod
rem  on a machine where the installer bat was lost.
rem ============================================================
set "GH_USER=zhubaohi"
set "GH_REPO=FF7R-DLSS5"

set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"

echo FF7 Rebirth - DLSS 5 (RenodX) uninstaller
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/%GH_USER%/%GH_REPO%/main/uninstall.ps1' -OutFile uninstall-dlss5.ps1"
if not exist uninstall-dlss5.ps1 (
  rem offline fallback: a copy is cached by the installer
  if exist "%LOCALAPPDATA%\FF7R-DLSS5Kit\uninstall.ps1" copy /y "%LOCALAPPDATA%\FF7R-DLSS5Kit\uninstall.ps1" uninstall-dlss5.ps1 >nul
)
if not exist uninstall-dlss5.ps1 (
  echo.
  echo Could not obtain uninstall.ps1. Check your internet connection.
  echo.
  pause
  exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File uninstall-dlss5.ps1
pause
