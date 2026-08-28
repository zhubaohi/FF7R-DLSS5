@echo off
setlocal
cd /d "%~dp0"
rem ============================================================
rem  FF7 Rebirth - DLSS 5 Neural Rendering (RenodX)
rem  One-click installer.
rem
rem  HOW TO USE (players):
rem    1. Put this file into your FF7R game folder (the one that
rem       contains  End\Binaries\Win64\ff7rebirth_.exe  )
rem    2. Double-click it.
rem
rem  HOW TO SHARE (you, the repo owner):
rem    Open this file in Notepad and change zhubaohi
rem    on the next line to your real GitHub username, save, then
rem    share this file.  Players double-click it and that's all.
rem ============================================================
set "GH_USER=zhubaohi"
set "GH_REPO=FF7R-DLSS5"

set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"

echo FF7 Rebirth - DLSS 5 (RenodX) installer
echo Downloading installer script from %GH_USER%/%GH_REPO% on GitHub ...
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/%GH_USER%/%GH_REPO%/main/install.ps1' -OutFile install.ps1"
if not exist install.ps1 (
  echo.
  echo Could not download install.ps1.
  echo  - check your internet connection
  echo  - make sure the GitHub repo %GH_USER%/%GH_REPO% is public
  echo  - if you are the repo owner: make sure you uploaded install.ps1 to the repo
  echo.
  goto :end
)
echo Running the installer ...
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File install.ps1 -RepoUrl "https://github.com/%GH_USER%/%GH_REPO%"
:end
echo.
pause
