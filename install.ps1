# ============================================================================
#  FF7 Rebirth - DLSS 5 Neural Rendering (RenodX) - Installer
#
#  Normal usage:  drop install.bat into your FF7R game folder and double-click
#  it.  That bat downloads THIS script and runs it with your repo URL.
#
#  What it does (all files are downloaded from your GitHub repo, ReShade has
#  an official reshade.me fallback):
#    1. ReShade 6.8.0                     (silent install, only if missing)
#    2. RenoDX - FF7 Rebirth build        (official snapshot)
#    3. renodx-dlss5-v2.5                 ("DLSS 5 Neural Rendering" addon)
#    4. NVIDIA DLSS 310.8 SDK files       (uses your game's own copies when
#                                          available, otherwise the set from
#                                          the GitHub repo)
#    5. ReShade.ini fix:  [ADDON] LoadFromDllMain = the DLSS addon.
#       This is the fix for the in-game "error code 225" and is MANDATORY.
#       Your original ReShade.ini is backed up as ReShade.ini.dlss5kit.bak.
#
#  Optional parameters (advanced):
#    -RepoUrl <url>   GitHub repo root, e.g. https://github.com/user/FF7R-DLSS5
#    -GameDir <path>  path to ff7rebirth_.exe, its folder, or the game root
#    -CacheDir <path> where downloaded files are cached
#    -Yes             answer yes to all prompts
# ============================================================================
#Requires -Version 5.1

param(
    [string]$RepoUrl  = "",
    [string]$GameDir  = "",
    [string]$CacheDir = "",
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$ProgressPreference = 'SilentlyContinue'
$script:Yes = [bool]$Yes

# ---------------------------- configuration --------------------------------
# Default repo when the script is run directly without -RepoUrl (for example
# the one line command from the README).  install.bat passes -RepoUrl too.
$script:RepoUrl = $RepoUrl.TrimEnd('/')
if (-not $script:RepoUrl) { $script:RepoUrl = 'https://github.com/zhubaohi/FF7R-DLSS5' }
$script:RepoIsPlaceholder = $script:RepoUrl -match 'YOUR_GITHUB_USERNAME'
$script:ReleaseUrl = "$script:RepoUrl/releases/download/v1"
$script:RawUrl     = "$script:RepoUrl/raw/main"
if (-not $CacheDir) { $CacheDir = Join-Path $env:LOCALAPPDATA 'FF7R-DLSS5Kit' }
$script:CacheDir = $CacheDir

# Offline (Nexus) mode: when the script sits next to a 'files' folder that
# holds all the artifacts (the Nexus bundle layout), the installer NEVER
# touches the internet and copies everything from the local bundle.
$script:OfflineDir = $null
if (Test-Path (Join-Path $PSScriptRoot 'files')) {
    $script:OfflineDir = (Resolve-Path (Join-Path $PSScriptRoot 'files')).Path
}
$script:Offline = [bool]$script:OfflineDir

$script:SetupFile    = 'ReShade_Setup_6.8.0_Addon.exe'
$script:MainFile     = 'renodx-ff7rebirth.addon64'
$script:DlssFile     = 'renodx-dlss5-v2.5.addon64'
# The complete NVIDIA Streamline/DLSS 310.8 set (14 files): the 11 runtime
# DLLs plus 3 license files.  Copying the whole set is what was tested and
# proven working in-game, so the installer installs all of it.
$script:NvidiaFiles = @(
    'nvngx_dlss.dll','nvngx_dlssg.dll','nvngx_dlssnr.dll',
    'sl.common.dll','sl.dlss.dll','sl.dlss_g.dll','sl.dlss_nr.dll',
    'sl.interposer.dll','sl.nis.dll','sl.pcl.dll','sl.reflex.dll',
    'nis.license.txt','nvngx_dlss.license.txt','reflex.license.txt'
)
$OneMB = 1MB

# ---------------------------- output helpers -------------------------------
function Write-Info([string]$msg) { Write-Host "  [i] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Bad([string]$msg)  { Write-Host "  [X] $msg" -ForegroundColor Red }
function Write-Step([string]$msg) { Write-Host ""; Write-Host "== $msg ==" -ForegroundColor White -BackgroundColor DarkBlue }
function Fail([string]$msg) {
    Write-Bad $msg
    if ($script:RepoIsPlaceholder) {
        Write-Warn "The GitHub repo URL is still the default placeholder."
        Write-Warn "Edit GH_USER in install.bat (or re-run with:  -RepoUrl https://github.com/<you>/FF7R-DLSS5)."
    }
    Write-Host ""; Read-Host "Press Enter to exit" | Out-Null; exit 1
}
function Confirm-YesNo([string]$question) {
    if ($script:Yes) { return $true }
    $answer = Read-Host "$question (Y/N)"
    return ($answer -match '^[Yy]')
}

# ---------------------------- game detection -------------------------------
function Resolve-GamePaths([string]$path) {
    # Returns [pscustomobject]@{ Root; Win64 } or $null.
    if (-not $path) { return $null }
    if (Test-Path $path -PathType Leaf) {
        if ((Split-Path $path -Leaf) -eq 'ff7rebirth_.exe') {
            $win64 = Split-Path $path -Parent
            if ($win64 -like '*\End\Binaries\Win64') {
                return [pscustomobject]@{ Root = (Split-Path (Split-Path (Split-Path $win64))); Win64 = $win64 }
            }
            return [pscustomobject]@{ Root = $null; Win64 = $win64 }
        }
        return $null
    }
    if (Test-Path $path -PathType Container) {
        if (Test-Path (Join-Path $path 'End\Binaries\Win64\ff7rebirth_.exe')) {
            return [pscustomobject]@{ Root = $path; Win64 = (Join-Path $path 'End\Binaries\Win64') }
        }
        if (Test-Path (Join-Path $path 'ff7rebirth_.exe')) {
            if ($path -like '*\End\Binaries\Win64') {
                return [pscustomobject]@{ Root = (Split-Path (Split-Path (Split-Path $path))); Win64 = $path }
            }
            return [pscustomobject]@{ Root = $null; Win64 = $path }
        }
    }
    return $null
}

function Get-SteamRoots {
    $roots = @()
    $steamPath = $null
    try {
        $steamKey = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
        if ($steamKey) {
            $steamPath = $steamKey.SteamPath
            if (-not $steamPath) { $steamPath = $steamKey.InstallPath }
        }
    } catch {}
    if ($steamPath) { $steamPath = ($steamPath -replace '/', '\').TrimEnd('\') }
    if ($steamPath -and (Test-Path $steamPath)) {
        $roots += $steamPath
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($line in (Get-Content $vdf)) {
                # new Steam vdf format:  "path"		"C:\\..."
                if ($line -match '^\s*"path"\s+"(.+?)"\s*$') {
                    $r = $Matches[1] -replace '\\\\', '\'
                    if (Test-Path (Join-Path $r 'steamapps')) { $roots += $r }
                }
                # old Steam vdf format:  "0"		"C:\\..."
                elseif ($line -match '^\s*"\d+"\s+"(.+?)"\s*$') {
                    $r = $Matches[1] -replace '\\\\', '\'
                    if (Test-Path (Join-Path $r 'steamapps')) { $roots += $r }
                }
            }
        }
    }
    return ($roots | Select-Object -Unique)
}

function Get-GamePaths {
    # 1) explicit -GameDir
    if ($GameDir) {
        $r = Resolve-GamePaths $GameDir
        if ($r) { return $r }
        Write-Warn "Could not validate the -GameDir path: $GameDir"
    }
    # 2) this script was dropped into the game folder (normal usage)
    if ($PSScriptRoot) {
        $r = Resolve-GamePaths $PSScriptRoot
        if ($r) { return $r }
    }
    # 3) Steam libraries
    foreach ($sr in (Get-SteamRoots)) {
        $c = Join-Path $sr 'steamapps\common\FINAL FANTASY VII REBIRTH'
        $r = Resolve-GamePaths $c
        if ($r) { return $r }
    }
    # 4) common locations on any drive
    $drives = @()
    try { $drives = (Get-PSDrive -PSProvider FileSystem).Root } catch {}
    foreach ($d in $drives) {
        foreach ($base in @("$d`SteamLibrary\steamapps\common", "$d`Games", "$d`Program Files\Epic Games", "$d`Program Files (x86)\Epic Games", "$d`Program Files", "$d`Program Files (x86)", $d)) {
            $r = Resolve-GamePaths (Join-Path $base 'FINAL FANTASY VII REBIRTH')
            if ($r) { return $r }
        }
    }
    return $null
}

# ---------------------------- downloads ------------------------------------
function Invoke-FileDownload([string[]]$urls, [string]$dest, [long]$minSize) {
    foreach ($u in $urls) {
        Write-Host "  downloading: $dest"
        Write-Host "  from:        $u"
        try {
            Invoke-WebRequest -Uri $u -OutFile $dest -UseBasicParsing -TimeoutSec 900
            $size = (Get-Item $dest).Length
            if ($size -ge $minSize) { return $dest }
            Write-Warn "download from $u looks invalid ($size bytes) - trying next source..."
        } catch {
            Write-Warn "download failed: $($_.Exception.Message)"
        }
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
    return $null
}

# Resolves one artifact: cache first, then the local bundle (offline mode),
# then a download. Returns the cache path, or $null when not obtainable.
function Get-Artifact([string]$name, [string[]]$urls, [long]$minSize) {
    $dest = Join-Path $script:CacheDir $name
    if (Test-Path $dest) {
        if ((Get-Item $dest).Length -ge $minSize) { return $dest }
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
    if ($script:OfflineDir) {
        $local = Join-Path $script:OfflineDir $name
        if (Test-Path $local) {
            if ((Get-Item $local).Length -ge $minSize) {
                Write-Host "  from local bundle: $name"
                Copy-Item $local $dest -Force
                return $dest
            }
            Fail "$name in the local bundle is too small - the bundle may be incomplete."
        }
        Fail "Offline mode: $name is missing from the local bundle (expected in: $script:OfflineDir)."
    }
    return (Invoke-FileDownload $urls $dest $minSize)
}

Write-Host ""
Write-Host "FF7 Rebirth - DLSS 5 Neural Rendering (RenodX) - Installer" -ForegroundColor Magenta
if ($script:Offline) {
    Write-Host "Mode: offline bundle (no internet needed) - $script:OfflineDir"
} else {
    Write-Host "Source: $script:RepoUrl"
    if ($script:RepoIsPlaceholder) { Write-Warn "repo URL is still the placeholder - make sure you edited install.bat" }
}

# ---------------------------- 1. locate game -------------------------------
Write-Step "Locating FINAL FANTASY VII REBIRTH"
$paths = Get-GamePaths
if (-not $paths) {
    Write-Warn "I could not find FINAL FANTASY VII REBIRTH automatically."
    Write-Warn "Open File Explorer, go to the game folder that contains 'End\Binaries\Win64\ff7rebirth_.exe',"
    Write-Warn "copy its full path from the address bar, and paste it below."
    while (-not $paths) {
        $try = Read-Host "Paste the game folder path (type 'q' to quit)"
        if ($try -match '^[Qq]$') { Write-Host "Cancelled."; exit 0 }
        if (-not $try) { Write-Warn "Nothing pasted. Try again."; continue }
        $paths = Resolve-GamePaths $try
        if (-not $paths) { Write-Warn "That does not look like the FF7R game folder. Try again." }
    }
}
$script:GameRoot = $paths.Root
$script:Win64    = $paths.Win64
$script:GameExe  = Join-Path $script:Win64 'ff7rebirth_.exe'
if (-not (Test-Path $script:GameExe)) {
    Fail "ff7rebirth_.exe not found in: $script:Win64"
}
Write-Ok "Game found: $script:Win64"

# writability check
try {
    $testFile = Join-Path $script:Win64 ".dlss5kit-write-test"
    Set-Content -Path $testFile -Value "ok" -Force
    Remove-Item $testFile -Force
    Write-Ok "Game folder is writable"
} catch {
    Fail "The game folder is not writable with your current account. Close this window and re-run install.bat as administrator."
}

# ---------------------------- 2. hardware ----------------------------------
Write-Step "Checking hardware"
$nvGpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' })
if ($nvGpus.Count -gt 0) {
    foreach ($g in $nvGpus) { Write-Ok "NVIDIA GPU: $($g.Name)" }
    $hasFifty = $false
    foreach ($g in $nvGpus) { if ($g.Name -match 'RTX 5\d\d') { $hasFifty = $true } }
    if (-not $hasFifty) {
        Write-Warn "No RTX 50 series GPU found among your NVIDIA GPUs."
        Write-Warn "From player reports, DLSS 5 Neural Rendering only runs on 50 series cards, so this mod may not work for you."
        if (-not (Confirm-YesNo "Continue anyway?")) { Write-Host ""; Read-Host "Press Enter to exit" | Out-Null; exit 0 }
    }
} else {
    Write-Warn "No NVIDIA GPU detected. This mod requires an NVIDIA (RTX) GPU to work."
    if (-not (Confirm-YesNo "Continue anyway?")) { Write-Host ""; Read-Host "Press Enter to exit" | Out-Null; exit 0 }
}

# ---------------------------- 3. reshade check ------------------------------
$reshadeIni = Join-Path $script:Win64 'ReShade.ini'
$reshadeDll = Join-Path $script:Win64 'd3d12.dll'
$reshadeInstalled = $false
$reshadeVersionOk = $false
if ((Test-Path $reshadeIni) -and (Test-Path $reshadeDll)) {
    $prod = (Get-Item $reshadeDll).VersionInfo.ProductName
    $ver  = (Get-Item $reshadeDll).VersionInfo.ProductVersion
    if ($prod -match 'ReShade') {
        $reshadeInstalled = $true
        if ($ver -match '^6\.8\.') {
            $reshadeVersionOk = $true
            Write-Ok "ReShade $ver is installed - nothing to do"
        } else {
            Write-Warn "ReShade $ver is installed, but this mod needs ReShade 6.8.0 or newer."
        }
    } else {
        Write-Warn "d3d12.dll is present but is not ReShade (product: '$prod')."
        Write-Warn "If another overlay/proxy uses d3d12.dll, it may conflict with ReShade."
    }
} else {
    Write-Info "ReShade not found - it will be downloaded and installed."
}

# ---------------------------- 4. downloads ----------------------------------
if ($script:Offline) { Write-Step "Preparing files (offline bundle)" } else { Write-Step "Downloading files" }
New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null

# nvidia dlls: prefer the game's own copies
$nvGameDir = $null
if ($script:GameRoot) {
    foreach ($c in @(
        (Join-Path $script:GameRoot 'Engine\Plugins\DLSSSubset\Binaries\ThirdParty\Win64'),
        (Join-Path $script:GameRoot 'Engine\Plugins\StreamlineSubset\Binaries\ThirdParty\Win64'))) {
        if (Test-Path (Join-Path $c 'nvngx_dlssnr.dll')) { $nvGameDir = $c; break }
    }
}
# Always install the known good 310.8 set that ships with this mod: in the
# vast majority of installs the user's own game files are missing or stale,
# and the proven set is the one we carry.  Only skip when the complete set
# is already placed next to the addon by a previous install.
$needNvidia = $true
if ($nvGameDir) {
    Write-Ok "your game ships NVIDIA files too, but this mod installs the known good set it carries"
}
$alreadyFull = $true
foreach ($dll in $script:NvidiaFiles) {
    if (-not (Test-Path (Join-Path $script:Win64 $dll))) { $alreadyFull = $false; break }
}
if ($alreadyFull) {
    Write-Ok "NVIDIA files already sit next to the addon - nothing to do"
    $needNvidia = $false
}

$setupExe = Get-Artifact $script:SetupFile @(
    "$($script:ReleaseUrl)/$($script:SetupFile)",
    'https://www.reshade.me/releases/ReShade-6.8.0-Addon-setup.exe'
) $OneMB
if (-not $setupExe) { Fail "Could not obtain the ReShade 6.8.0 installer." }
Write-Ok "ReShade setup ready"

$c1 = Get-Artifact $script:MainFile @("$($script:ReleaseUrl)/$($script:MainFile)") 100KB
if (-not $c1) { Fail "Could not obtain $script:MainFile." }
$c2 = Get-Artifact $script:DlssFile @("$($script:ReleaseUrl)/$($script:DlssFile)") 100KB
if (-not $c2) { Fail "Could not obtain $script:DlssFile." }
Write-Ok "addons ready"

# keep a copy of the uninstall script for offline use
$cu = Join-Path $script:CacheDir 'uninstall.ps1'
if (-not (Test-Path $cu)) {
    $src = Join-Path $PSScriptRoot 'uninstall.ps1'
    if (Test-Path $src) {
        Copy-Item $src $cu -Force
    } else {
        Get-Artifact 'uninstall.ps1' @("$($script:RawUrl)/uninstall.ps1") 1KB | Out-Null
    }
}

# The offline bundle may carry the 14 SDK files as a plain folder
# (files\nvidia) so the pack never contains a zip inside a zip.
$script:BundleNvDir = $null
if ($script:OfflineDir) {
    $d = Join-Path $script:OfflineDir 'nvidia'
    if (Test-Path (Join-Path $d 'nvngx_dlssnr.dll')) { $script:BundleNvDir = $d }
}

if ($needNvidia) {
    if ($script:BundleNvDir) {
        Write-Ok "NVIDIA DLSS SDK (310.8) from the local bundle folder"
    } else {
        $nvidiaZip = Join-Path $script:CacheDir 'nvidia.zip'
        if (-not (Test-Path $nvidiaZip)) {
            $ok = Get-Artifact 'nvidia.zip' @("$($script:ReleaseUrl)/nvidia.zip") ([long]100MB)
            if (-not $ok) {
                Write-Info "single nvidia.zip not available - trying the split parts..."
                $p1 = Get-Artifact 'nvidia-part1.zip' @("$($script:ReleaseUrl)/nvidia-part1.zip") ([long]70MB)
                $p2 = Get-Artifact 'nvidia-part2.zip' @("$($script:ReleaseUrl)/nvidia-part2.zip") ([long]70MB)
                if ($p1 -and $p2) {
                    $out = [System.IO.File]::Create($nvidiaZip)
                    [System.IO.File]::OpenRead($p1).CopyTo($out)
                    [System.IO.File]::OpenRead($p2).CopyTo($out)
                    $out.Close()
                }
                else { Fail "Could not obtain the NVIDIA DLSS SDK files (nvidia.zip or nvidia-part1/2.zip)." }
            }
        }
        Write-Ok "NVIDIA DLSS SDK (310.8) ready"
    }
}

# ---------------------------- 5. install reshade ----------------------------
if (-not $reshadeInstalled) {
    Write-Step "Installing ReShade 6.8.0"
    Unblock-File $setupExe -ErrorAction SilentlyContinue
    & $setupExe --headless --api d3d12 $script:GameExe 2>&1 | Out-Host
    $code = $LASTEXITCODE
    if ((Test-Path $reshadeIni) -and (Test-Path $reshadeDll)) {
        Write-Ok "ReShade 6.8.0 installed"
        $reshadeInstalled = $true
        $reshadeVersionOk = $true
    }
    else {
        Write-Bad "ReShade setup did not complete (exit code: $code)."
        Write-Warn "Try again, or install ReShade 6.8 manually, then re-run install.bat."
        Write-Host ""; Read-Host "Press Enter to exit" | Out-Null; exit 1
    }
}
elseif (-not $reshadeVersionOk) {
    Write-Info "Opening the ReShade setup - please click 'Update' to upgrade to 6.8.0."
    Unblock-File $setupExe -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $setupExe -ArgumentList @('--api', 'd3d12', "`"$script:GameExe`"") -PassThru
    $p.WaitForExit()
    $ver = (Get-Item $reshadeDll).VersionInfo.ProductVersion
    if ($ver -match '^6\.8\.') {
        Write-Ok "ReShade updated to $ver"
        $reshadeVersionOk = $true
    } else {
        Write-Warn "ReShade is still $ver. The DLSS addon may not work until you update it."
    }
}

# ---------------------------- 6. addons --------------------------------------
Write-Step "Installing addons"
Copy-Item $c1 (Join-Path $script:Win64 $script:MainFile) -Force
Write-Ok "$script:MainFile (RenoDX for FF7 Rebirth)"
Copy-Item $c2 (Join-Path $script:Win64 $script:DlssFile) -Force
Write-Ok "$script:DlssFile (DLSS 5 Neural Rendering)"

# ---------------------------- 7. nvidia dlls ---------------------------------
if ($needNvidia) {
    Write-Step "Installing NVIDIA DLSS SDK files (310.8)"
    if ($script:BundleNvDir) {
        $stage = $script:BundleNvDir
    } else {
        $stage = Join-Path $script:CacheDir 'nvidia'
        if (-not (Test-Path $stage)) {
            New-Item -ItemType Directory -Force -Path $stage | Out-Null
            Expand-Archive -Path $nvidiaZip -DestinationPath $stage -Force
        }
    }
    $missing = @()
    foreach ($dll in $script:NvidiaFiles) {
        $src = Join-Path $stage $dll
        if (Test-Path $src) { Copy-Item $src (Join-Path $script:Win64 $dll) -Force }
        else { $missing += $dll }
    }
    Write-Ok "NVIDIA SDK files placed next to the addon"
    if ($missing -contains 'nvngx_dlssnr.dll') {
        Write-Warn "nvngx_dlssnr.dll is missing - Neural Rendering will NOT work until this is fixed."
    } elseif ($missing.Count -gt 0) { Write-Warn "Not found: $($missing -join ', ')" }
}

# ---------------------------- 8. reshade.ini fix -----------------------------
Write-Step "Configuring ReShade.ini (the fix for in-game error 225)"
if (-not (Test-Path $reshadeIni)) {
    Write-Info "Creating a new ReShade.ini..."
    [System.IO.File]::WriteAllLines($reshadeIni, @('[ADDON]'))
}
$iniBackup = "$reshadeIni.dlss5kit.bak"
if (-not (Test-Path $iniBackup)) {
    Copy-Item $reshadeIni $iniBackup -Force
    Write-Ok "Backup saved: ReShade.ini.dlss5kit.bak"
}

function Update-LoadFromDllMain([string]$iniPath, [string]$addonFile) {
    $lines = [System.IO.File]::ReadAllLines($iniPath)
    $keyPrefix = 'LoadFromDllMain='
    $keyIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith($keyPrefix)) { $keyIdx = $i; break }
    }
    if ($keyIdx -ge 0) {
        $value = $lines[$keyIdx].Substring($keyPrefix.Length)
        $entries = @(); $cur = ''
        foreach ($ch in $value.ToCharArray()) {
            if ([int]$ch -eq 0) { $entries += $cur; $cur = '' } else { $cur += $ch }
        }
        $entries += $cur
        if ($entries -notcontains $addonFile) {
            $entries += $addonFile
            $lines[$keyIdx] = $keyPrefix + ($entries -join [string][char]0)
            [System.IO.File]::WriteAllLines($iniPath, $lines)
            return 'added'
        }
        return 'already'
    }
    $hasSection = $false
    foreach ($l in $lines) { if ($l.Trim() -eq '[ADDON]') { $hasSection = $true; break } }
    if (-not $hasSection) { $lines += ''; $lines += '[ADDON]' }
    $out = @(); $inserted = $false
    foreach ($l in $lines) {
        $out += $l
        if (-not $inserted -and $l.Trim() -eq '[ADDON]') { $out += "$keyPrefix$addonFile"; $inserted = $true }
    }
    [System.IO.File]::WriteAllLines($iniPath, $out)
    return 'created'
}

$iniResult = Update-LoadFromDllMain $reshadeIni $script:DlssFile
switch ($iniResult) {
    'already' { Write-Ok "LoadFromDllMain already contains $script:DlssFile" }
    'added'   { Write-Ok "Added LoadFromDllMain=$script:DlssFile to ReShade.ini" }
    'created' { Write-Ok "Created [ADDON] section with LoadFromDllMain=$script:DlssFile" }
}

# ---------------------------- 9. uninstall bat --------------------------------
if ($script:GameRoot) {
    if ($cu) { Copy-Item $cu (Join-Path $script:GameRoot 'uninstall.ps1') -Force }
    $uninstBat = Join-Path $script:GameRoot 'uninstall-dlss5.bat'
    if ($script:Offline) {
        $bat = @"
@echo off
setlocal
cd /d "%~dp0"
rem FF7 Rebirth DLSS 5 (RenodX) uninstaller - generated by the installer
set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"
if not exist uninstall.ps1 (
  echo uninstall.ps1 is missing next to this file.
  echo Re-run the installer from the mod folder and it will restore it.
  pause
  exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
pause
"@
    } else {
        $bat = @"
@echo off
setlocal
cd /d "%~dp0"
rem FF7 Rebirth DLSS 5 (RenodX) uninstaller - generated by the installer
set "PS=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS=pwsh.exe"
if not exist uninstall.ps1 "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072; iwr -UseBasicParsing '$($script:RawUrl)/uninstall.ps1' -OutFile uninstall.ps1"
if not exist uninstall.ps1 if exist "%LOCALAPPDATA%\FF7R-DLSS5Kit\uninstall.ps1" copy /y "%LOCALAPPDATA%\FF7R-DLSS5Kit\uninstall.ps1" uninstall.ps1 >nul
if not exist uninstall.ps1 (
  echo Could not obtain uninstall.ps1. Re-run the installer.
  pause
  exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
pause
"@
    }
    [System.IO.File]::WriteAllText($uninstBat, ($bat -replace "`n", "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "Created $uninstBat (double-click it later to remove everything)"
}

# ---------------------------- 10. verify ---------------------------------------
Write-Step "Verification"
$checks = @(
    @{ Name = 'ReShade 6.8 proxy (d3d12.dll)';        Test = { Test-Path $reshadeDll } },
    @{ Name = 'ReShade.ini present';                  Test = { Test-Path $reshadeIni } },
    @{ Name = 'RenoDX addon installed';               Test = { Test-Path (Join-Path $script:Win64 $script:MainFile) } },
    @{ Name = 'DLSS 5 addon installed';               Test = { Test-Path (Join-Path $script:Win64 $script:DlssFile) } },
    @{ Name = 'nvngx_dlssnr.dll beside the addon';    Test = { Test-Path (Join-Path $script:Win64 'nvngx_dlssnr.dll') } },
    @{ Name = 'LoadFromDllMain entry in ReShade.ini'; Test = {
        $c = [System.IO.File]::ReadAllText($reshadeIni)
        $c.Contains('LoadFromDllMain=') -and $c.Contains($script:DlssFile)
    } }
)
$allGood = $true
foreach ($c in $checks) {
    if (& $c.Test) { Write-Ok $c.Name } else { Write-Bad $c.Name; $allGood = $false }
}

Write-Host ""
if ($allGood) {
    Write-Host "EVERYTHING IS INSTALLED." -ForegroundColor Green
    Write-Host ""
    Write-Host "What to do next:" -ForegroundColor White
    Write-Host "  1. Start FINAL FANTASY VII REBIRTH as usual."
    Write-Host "  2. In game, press the HOME key to open the ReShade overlay."
    Write-Host "  3. Click the 'Add-ons' tab: 'DLSS 5 Neural Rendering' should be there."
    Write-Host "     'Enable DLSS Neural Rendering' is on by default."
    Write-Host "  4. Watch the status text at the bottom of that panel:"
    Write-Host "       - 'Successful NR frames' counting up = it works."
    Write-Host "       - 'STANDBY/FAILED' = something is still missing; check the 'Log' tab."
    Write-Host ""
    Write-Host "Optional: on an RTX 50 series GPU with NVIDIA driver 616.56 or newer you" -ForegroundColor DarkGray
    Write-Host "can also enable 'Neural Uplift' in the same panel." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "To undo everything later, double-click uninstall-dlss5.bat in the game folder." -ForegroundColor DarkGray
    Write-Host "(the installer files can be deleted after a successful install - they are only needed for re-installs.)" -ForegroundColor DarkGray
} else {
    Write-Warn "Install finished with problems - check the messages above."
}