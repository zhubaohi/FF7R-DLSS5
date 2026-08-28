# FINAL FANTASY VII REBIRTH — DLSS 5 Neural Rendering (RenodX)

**What is this?** A one-click install that adds NVIDIA **DLSS 5 "Neural Rendering"** post-processing to *FINAL FANTASY VII Rebirth* on PC — neural upscaling / re-lighting on top of the game's built-in DLSS, driven by [ReShade](https://github.com/crosire/reshade) 6.8, [RenoDX](https://github.com/clshortfuse/renodx) (FF7 Rebirth build) and the community **"DLSS 5 Neural Rendering" addon v2.5** (from the RenoDX Discord).

> ⚠️ **Experimental.** The DLSS 5 addon is an early community build. Expect rough edges and updates. This project is **not** affiliated with Square Enix, NVIDIA or the RenoDX project.

---

## Install — 2 steps (players)

1. Download `install.bat` from this repo.
2. Put it into your **FF7R game folder** — the folder that contains `End\Binaries\Win64\ff7rebirth_.exe` — and **double-click it**.

That's all. No administrator rights needed for Steam/GOG installs, no manual file copying. The bat downloads the installer script, which then:

| Step | What happens |
|---|---|
| 1 | Finds your game (auto-detect, or asks once if it can't) |
| 2 | Downloads **ReShade 6.8.0** (official, silent install) — only if you don't have it |
| 3 | Downloads **RenoDX** (FF7 Rebirth build, official snapshot) |
| 4 | Downloads the **DLSS 5 Neural Rendering v2.5** addon |
| 5 | Installs the **NVIDIA DLSS 310.8 SDK files** — uses your game's own copies (in `Engine\Plugins\DLSSSubset`) when available, otherwise the set from this repo |
| 6 | Applies the **`ReShade.ini` fix** (`[ADDON] LoadFromDllMain`) — *mandatory*, without it the addon fails in-game with error 225. Your original ini is backed up as `ReShade.ini.dlss5kit.bak` |
| 7 | Runs a final verification checklist |

Files are downloaded from this GitHub repo (ReShade additionally falls back to the official reshade.me) and are cached in `%LOCALAPPDATA%\FF7R-DLSS5Kit` — the game folder only receives the files the mod actually needs.

## Requirements

- FINAL FANTASY VII REBIRTH (Steam or GOG)
- An **NVIDIA RTX GPU** (the DLSS SDK is NVIDIA-only)
- Internet connection during install (≈ 160 MB total, mostly the NVIDIA files — only if your game doesn't already ship them)
- Recent NVIDIA driver (driver **616.56+** if you want **Neural Uplift**)

## First in-game run — how to check it works

1. Start the game normally. Press **HOME** to open the ReShade overlay.
2. **Add-ons** tab → **DLSS 5 Neural Rendering** → make sure **Enable DLSS Neural Rendering** is checked (default: on).
3. Read the status block at the bottom of that panel:

   | Line | Healthy value |
   |---|---|
   | `DLSSNR v310.8.0:` | `RUNNING` (not `STANDBY/FAILED`) |
   | `NGX hooks` | `creates … \| evaluations` counting up |
   | `Successful NR frames` | **counting up** — this is the one that matters |
   | `Latest NR NGX result` | `0x00000000` (not `0xBAD…`) |

4. If it shows `STANDBY/FAILED`, click the **"Reset NR feature and clear failure latch"** button once and give the game a minute (it latches after the first failure).

### Suggested starting settings

- **Enable Upscaling** — on (DLSS upscales from your render scale)
- **NR Intensity** — 1.00–1.05 (default 1.01); higher = more aggressive re-lighting
- **Local Tone / Structure Strength** — 1.00 (defaults are fine)
- **Neural Uplift** — RTX 50 series + driver 616.56+ only

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Could not download install.ps1" | Offline / repo not public / GH_USER not edited | Check internet; repo must be **public**; edit `GH_USER` in `install.bat` to the uploader's GitHub username |
| "Could not download …" for other files | Release assets missing from the repo | The repo owner must upload all files from the `files/` set (see below) |
| `error code 225` in `ReShade.log` | addon not loaded early enough | Re-run `install.bat` (re-applies the `LoadFromDllMain` fix); verify `ReShade.ini` has `LoadFromDllMain=renodx-dlss5-v2.5.addon64` under `[ADDON]` |
| `STANDBY/FAILED`, log says `nvngx_dlssnr.dll was not found beside the addon` | NVIDIA SDK files not next to the addon | Re-run `install.bat` (copies the SDK set); verify `nvngx_dlssnr.dll` is in `End\Binaries\Win64` |
| `Successful NR frames: 0` forever | feature init failed | Click **Reset NR feature and clear failure latch**, or restart the game; check the **Log** tab |
| No ReShade overlay (HOME does nothing) | ReShade missing / outdated | Re-run `install.bat`; verify the checklist said `ReShade 6.8.x installed` |
| GOG / custom install folder | auto-detect missed it | the installer will ask you to paste the game folder path |
| SmartScreen/Defender complains | unsigned executables (normal for ReShade/mods) | **More info → Run anyway**; or right-click → Properties → **Unblock** |

## Uninstall

Double-click **`uninstall-dlss5.bat`** (the installer creates it in your game folder). It removes both addons, the 11 `nvngx_*/sl.*` DLLs, restores your original `ReShade.ini` from the backup, and deletes the generated helper file. ReShade itself is kept (other mods may use it).

---

## For the repo owner (publishing this)

Everything the installer downloads lives in the `files/` set. One-time setup:

1. **Create a public GitHub repo** (name it `FF7R-DLSS5`, or edit `GH_REPO` in `install.bat` to match yours).
2. **Commit to the repo** (any branch, default `main`): `install.ps1`, `uninstall.ps1`, `README.md`.
3. **Create a release named `v1`** and upload these files from the `files/` folder as release assets:
   - `ReShade_Setup_6.8.0_Addon.exe` (4.3 MB)
   - `renodx-ff7rebirth.addon64` (4.1 MB, official RenoDX snapshot)
   - `renodx-dlss5-v2.5.addon64` (382 KB, community addon from the RenoDX Discord)
   - `nvidia.zip` (142.7 MB) — **upload via the GitHub CLI** (`gh release upload v1 files\nvidia.zip`); the web upload UI caps files at 100 MB
   - *or* upload `nvidia-part1.zip` + `nvidia-part2.zip` (73/76 MB) via the web UI instead — the installer detects and merges them automatically
4. **Edit `install.bat`**: replace `YOUR_GITHUB_USERNAME` with your GitHub username (line in the header block). That single file is what players download.
5. Done. Players drop `install.bat` into their game folder and double-click.

The scripts look like this:

```
https://github.com/<you>/FF7R-DLSS5/raw/main/install.ps1          (repo file)
https://github.com/<you>/FF7R-DLSS5/releases/download/v1/<file>   (release assets)
```

### File hashes (SHA-256, verify after upload)

| File | SHA-256 |
|---|---|
| `ReShade_Setup_6.8.0_Addon.exe` | `AFE4C8F13048306307983B8B3D41D5BF00A86820440B0E57DEA10950E1176445` |
| `renodx-ff7rebirth.addon64` | `9C1072103B63AB068C75468BE70324A0AF8249FE32C029868B91A704270B1520` |
| `renodx-dlss5-v2.5.addon64` | `87AEF9DDD937C7241E6BF8D8EFEA0045D63559135E254C60DAB316DB3D3A4AEE` |
| `nvidia.zip` | `2FE2583A7E4A75997CB0220AEEE1A68427AE8308E1ADEA3A229AF34FDE527491` |

*Verified on the reference machine during development. After uploading, run `Get-FileHash` on your uploaded files (or download them back) and compare — if you ever refresh a file (e.g. a newer RenoDX snapshot), update this table.*

## What each piece is

| Piece | Source | Notes |
|---|---|---|
| ReShade 6.8.0 (with add-on support) | official (reshade.me / this repo) | the hook layer that loads everything |
| RenoDX — FF7 Rebirth build | official RenoDX snapshot | game-specific injections & fixes |
| DLSS 5 Neural Rendering v2.5 | community build (RenoDX Discord) | the actual Neural Rendering post-pass |
| NVIDIA DLSS/Streamline SDK 310.8 | the same DLLs the game ships in `Engine\Plugins\DLSSSubset` | included so the kit works on any install |
| `LoadFromDllMain` ini fix | found while troubleshooting | the FF7R game inits its DLSS SDK before device creation; ReShade 6.8's `[ADDON] LoadFromDllMain` makes the proxy load the addon from `DllMain` (process start), which is required for the addon to succeed |

**Credits:** [crosire — ReShade](https://github.com/crosire/reshade) · [Carlos Lopez — RenoDX](https://github.com/clshortfuse/renodx) · "DLSS 5 Neural Rendering" addon (v2.5) from the RenoDX Discord · NVIDIA DLSS/Streamline SDK 310.8.