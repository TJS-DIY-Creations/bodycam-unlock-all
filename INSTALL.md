# Installation guide

This is the detailed, step-by-step version of the install section in [`README.md`](README.md).

## Before you start

- Close **Bodycam** completely (check Task Manager for `Bodycam-Win64-Shipping.exe`).
- If the game is installed under `C:\Program Files`, run `install.bat` as administrator (right-click → **Run as administrator**).
- Make sure **Steam is running and logged in** to the account you want to unlock.
- Know where Bodycam is installed. The default is:
  ```
  C:\Program Files (x86)\Steam\steamapps\common\Bodycam
  ```
  but many people use a second library such as `D:\SteamLibrary\steamapps\common\Bodycam`.

The installer finds the game through Steam's library configuration, so you normally do not need to enter a path.

## Package choices

### Full bundle

The full bundle contains the mod **and** a tested UE4SS installation (v3.0.1 Beta #0). Use it if you have never installed UE4SS.

1. Extract `Bodycam-Unlock-All-v1.0.0-full.zip` to any folder.
2. Double-click `install.bat`.
3. If Windows SmartScreen appears, click **More info → Run anyway**.
4. The installer prints the game folder it found and the mod folder it installed.
5. Launch Bodycam from Steam.
6. Wait at the main menu for about 30–60 seconds. The unlock is automatic.
7. Open the status file:
   ```
   <Bodycam>\Bodycam\Binaries\Win64\ue4ss\Mods\BodycamUnlockAll\Scripts\unlock_status.txt
   ```

If the installer cannot find the game:

```bat
install.bat -GamePath "D:\Games\SteamLibrary\steamapps\common\Bodycam"
```

You can pass the game root, the `Bodycam` project folder, the `Win64` folder, or the `Bodycam-Win64-Shipping.exe` path; the installer walks up from any of them.

### Mod-only package

Use this if UE4SS is already installed and working.

1. Extract `Bodycam-Unlock-All-v1.0.0-mod.zip`.
2. Double-click `install.bat`.
3. The installer verifies that `...\Win64\ue4ss\UE4SS.dll` exists. If it does not, install UE4SS from
   <https://github.com/UE4SS-RE/RE-UE4SS/releases> and run the installer again.
4. Launch the game and wait at the main menu.

## What the installer changes

| Path | Change |
| --- | --- |
| `...\Win64\ue4ss\` | Copied from the full bundle **only if UE4SS is not already installed**. |
| `...\Win64\dwmapi.dll` | Copied from the full bundle only when UE4SS is newly installed. Existing DLLs are backed up, never silently lost. |
| `...\Win64\ue4ss\Mods\BodycamUnlockAll\` | The mod. An existing `Scripts\config.lua` is preserved on update. |
| `...\Win64\ue4ss\Mods\mods.txt` | Adds `BodycamUnlockAll : 1`. A timestamped `.bak` copy is created first. |

The installer never deletes other mods and never edits `UE4SS-settings.ini`.

## Manual installation (both packages)

1. Copy the `BodycamUnlockAll` folder to:
   ```
   <Bodycam>\Bodycam\Binaries\Win64\ue4ss\Mods\BodycamUnlockAll
   ```
2. Edit `<Bodycam>\Bodycam\Binaries\Win64\ue4ss\Mods\mods.txt` and add:
   ```
   BodycamUnlockAll : 1
   ```
   Put it before the `; Built-in keybinds, do not move up!` line.
3. If you are installing UE4SS by hand from the full bundle, copy:
   - the bundle's `ue4ss` folder to `<Bodycam>\Bodycam\Binaries\Win64\ue4ss`
   - the bundle's `dwmapi.dll` to `<Bodycam>\Bodycam\Binaries\Win64\dwmapi.dll`
4. Start the game.

## Reading the status file

```
Bodycam Unlock All v1.0.0
Time: 2026-11-08 16:51:23
Stage: GRANTED
Owned: 2131/2131
Missing: 0
Method: GrantPromoItems
Elapsed: 27s
Detail: unlocked all shop items
Script: ...\BodycamUnlockAll\Scripts\
```

| Stage | Meaning |
| --- | --- |
| `STARTING` | The mod loaded and is waiting for the game world. |
| `WARMING_UP` | The shop table is loaded; waiting for Steam inventory. |
| `CHECKING` | Counting already-owned items. |
| `GRANTING` | Calling `GrantPromoItems`. |
| `VERIFYING` | Recounting ownership after the grant. |
| `GRANTED` | Success — the grant ran and every row is owned. |
| `ALREADY_UNLOCKED` | Success — every row was already owned, nothing was changed. |
| `FAILED:<reason>` | Something went wrong; see the `Detail:` line and the troubleshooting table in the README. |

`unlock_log.txt` contains the same information with timestamps for every stage and any errors.

## Updating

Install the new package over the old one. The installer replaces the Lua scripts but keeps your `config.lua` if you edited it. Your granted items are unaffected.

## Removing

Run `uninstall.bat` from the package, or delete the `BodycamUnlockAll` folder and its line in `mods.txt`.

Uninstalling does **not** revoke already-granted items. They are real Steam inventory ownership. It also does not remove UE4SS; remove UE4SS separately if you do not use it for other mods.
