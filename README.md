# FINAL FANTASY VII REBIRTH: DLSS 5 Neural Rendering (RenodX)

**What is this?** A one click install that adds NVIDIA **DLSS 5 "Neural Rendering"** to *FINAL FANTASY VII Rebirth* on PC: neural upscaling and relighting on top of the DLSS the game already ships, driven by [ReShade](https://github.com/crosire/reshade) 6.8, [RenoDX](https://github.com/clshortfuse/renodx) (the official FF7 Rebirth build) and the community **"DLSS 5 Neural Rendering" addon v2.5** from the RenoDX Discord.

> **EXPERIMENTAL.** The DLSS 5 addon is an early community build. Expect rough edges and updates. This project is not affiliated with Square Enix, NVIDIA or the RenoDX project.
>
> **Repo:** https://github.com/zhubaohi/FF7R-DLSS5 | **Release assets:** https://github.com/zhubaohi/FF7R-DLSS5/releases/tag/v1 | **Install file for players:** https://raw.githubusercontent.com/zhubaohi/FF7R-DLSS5/main/install.bat

## Install (players): 2 steps

1. Download `install.bat` from this repo.
2. Put it into your **FF7R game folder** (the folder that contains `End\Binaries\Win64\ff7rebirth_.exe`) and **double click it**.

That's all. No administrator rights needed, no manual file copying. The bat downloads the installer script, which then:

| Step | What happens |
|---|---|
| 1 | Finds your game (auto detect for Steam and Epic installs, or asks once if it can't) |
| 2 | Downloads **ReShade 6.8.0** (official, silent install). Only if you don't have it |
| 3 | Downloads **RenoDX** (FF7 Rebirth build, official snapshot) |
| 4 | Downloads the **DLSS 5 Neural Rendering v2.5** addon |
| 5 | Installs the **NVIDIA DLSS 310.8 SDK files**. Uses your game's own copies (in `Engine\Plugins\DLSSSubset`) when available, otherwise the complete set (11 DLLs + 3 license files) from this repo |
| 6 | Applies the **`ReShade.ini` fix** (`[ADDON] LoadFromDllMain`). Mandatory: without it the addon fails in game with error 225. Your original ini is backed up as `ReShade.ini.dlss5kit.bak` |
| 7 | Runs a final verification checklist |

Files are downloaded from this GitHub repo (ReShade additionally falls back to the official reshade.me) and are cached in `%LOCALAPPDATA%\FF7R-DLSS5Kit`. The game folder only receives the files the mod actually needs.

## Install with one command (optional, terminal users)

Copy and paste this single line into PowerShell or cmd and run it. It fetches the installer from this repo and runs it, so this method needs internet:

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=3072; $s = Join-Path $env:TEMP 'ff7r-dlss5-install.ps1'; iwr 'https://raw.githubusercontent.com/zhubaohi/FF7R-DLSS5/main/install.ps1' -UseBasicParsing -OutFile $s; & $s"
```

The installer finds your game automatically (Steam and Epic installs) or asks you to paste the game folder path. To point at a specific folder, replace the final `& $s` with `& $s -GameDir 'C:\path\to\your game folder'`.

## Requirements

* FINAL FANTASY VII REBIRTH on **Steam or Epic Games** (only the Steam install has been tested; if the installer can't find your Epic install it will ask for the path)
* An **NVIDIA RTX 50 series GPU**. From player reports, DLSS 5 Neural Rendering only runs on 50 series hardware. Older cards may not be able to run this mod
* Internet connection during install (about 160 MB, mostly the NVIDIA files, only if your game doesn't already ship them)
* Recent NVIDIA driver. Driver **616.56 or newer** if you want the **Neural Uplift** option on RTX 50 series cards
* If you already run ReShade 6.8 or newer, the installer keeps it. An older ReShade gets an update offer. If another proxy uses `d3d12.dll` in your game folder, expect possible conflicts

## First in game run: how to check it works

1. Start the game normally. Press **HOME** to open the ReShade overlay.
2. Open the **Add ons** tab, then **DLSS 5 Neural Rendering**, and make sure **Enable DLSS Neural Rendering** is checked (default: on).
3. Read the status block at the bottom of that panel:

   | Line | Healthy value |
   |---|---|
   | `DLSSNR v310.8.0:` | `RUNNING` (not `STANDBY/FAILED`) |
   | `NGX hooks` | `creates ... | evaluations` counting up |
   | `Successful NR frames` | **counting up** (this is the one that matters) |
   | `Latest NR NGX result` | `0x00000000` (not `0xBAD...`) |

4. If it shows `STANDBY/FAILED`, click the **"Reset NR feature and clear failure latch"** button once and give the game a minute (it latches after the first failure).

### Suggested starting settings

* **Enable Upscaling**: on (DLSS upscales from your render scale)
* **NR Intensity**: 1.00 to 1.05 (default 1.01). Higher is more aggressive relighting
* **Local Tone / Structure Strength**: 1.00 (defaults are fine)
* **Neural Uplift**: RTX 50 series + driver 616.56 or newer only

## Uninstall

Double click **`uninstall-dlss5.bat`** (the installer creates it in your game folder). It removes both addons, the 14 NVIDIA SDK files (11 `nvngx_*/sl.*` DLLs + license txts), restores your original `ReShade.ini` from the backup, and deletes the generated helper file. ReShade itself is kept (other mods may use it). You can then delete the installer bat files from the game folder.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Could not download install.ps1" | Offline, or GitHub unreachable | Check internet, re run |
| "Could not download ..." for other files | Release assets temporarily unreachable, or your cache is stale | Re run later. Delete `%LOCALAPPDATA%\FF7R-DLSS5Kit` to force fresh downloads |
| `error code 225` in `ReShade.log` | Addon not loaded early enough | Re run `install.bat` (re applies the `LoadFromDllMain` fix). Verify `ReShade.ini` has `LoadFromDllMain=renodx-dlss5-v2.5.addon64` under `[ADDON]` |
| `STANDBY/FAILED`, log says `nvngx_dlssnr.dll was not found beside the addon` | NVIDIA SDK files not next to the addon | Re run `install.bat` (copies the SDK set). Verify `nvngx_dlssnr.dll` is in `End\Binaries\Win64` |
| `Successful NR frames: 0` forever | Feature init failed | Click **Reset NR feature and clear failure latch**, or restart the game. Check the **Log** tab |
| No ReShade overlay (HOME does nothing) | ReShade missing or outdated | Re run `install.bat`. Verify the checklist said `ReShade 6.8.x installed` |
| Game not auto detected (Epic or custom layout) | Install location not in the scanned paths | The installer will ask you to paste the game folder path |
| SmartScreen / Defender warns | Unsigned executables (normal for ReShade and mods) | **More info, then Run anyway** (or right click, Properties, then **Unblock**) |

## What each piece is

| Piece | Source | Notes |
|---|---|---|
| ReShade 6.8.0 (with add on support) | official (reshade.me / this repo) | the hook layer that loads everything |
| RenoDX FF7 Rebirth build | official RenoDX snapshot | game specific injections and fixes |
| DLSS 5 Neural Rendering v2.5 | community build (RenoDX Discord, in the line of work started by speedlemur in Control and made generic by lecram) | the actual Neural Rendering post pass |
| NVIDIA DLSS/Streamline SDK 310.8 | the same files the game ships in `Engine\Plugins\DLSSSubset` (11 DLLs + 3 license files) | installed in full so the kit works on any install |
| `LoadFromDllMain` ini fix | found while troubleshooting | the FF7R game inits its DLSS SDK before device creation. ReShade 6.8's `[ADDON] LoadFromDllMain` makes the proxy load the addon from `DllMain` (process start), which is required for the addon to succeed |

## File hashes (SHA-256, as published on release v1)

| File | SHA-256 |
|---|---|
| `ReShade_Setup_6.8.0_Addon.exe` | `AFE4C8F13048306307983B8B3D41D5BF00A86820440B0E57DEA10950E1176445` |
| `renodx-ff7rebirth.addon64` | `9C1072103B63AB068C75468BE70324A0AF8249FE32C029868B91A704270B1520` |
| `renodx-dlss5-v2.5.addon64` | `87AEF9DDD937C7241E6BF8D8EFEA0045D63559135E254C60DAB316DB3D3A4AEE` |
| `nvidia.zip` | `731FECECF3D66FB07A0302382B4B2AE6CC30055E5218EFD2C5DD590C9EDCDFDE` |

*The values above are what release v1 serves today. Verify any downloaded file with `Get-FileHash <file>` (PowerShell) and compare.*

## Credits

**Credits:** [crosire, ReShade](https://github.com/crosire/reshade) | [shortfuse (Carlos Lopez), RenoDX](https://github.com/clshortfuse/renodx) | **speedlemur**, the original DLSS 5 implementation (Control) | **lecram**, the generic DLSS 5 addon used in other games (this mod builds on that line of work) | "DLSS 5 Neural Rendering" addon v2.5 (RenoDX Discord) | NVIDIA DLSS/Streamline SDK 310.8.