# Bodycam Unlock All

Unlocks **every cosmetic in Bodycam** as **real Steam inventory items** — operator skins, badges, weapon skins, attachments, stickers, flags and charms.

- **One click** — no menus, no keybinds
- **Automatic** — runs once at the main menu on every launch
- **Verified** — checks ownership against the game's shop table and writes a report
- **Persistent** — items are Steam inventory ownership, not a local save edit
- **2131 / 2131** shop items unlocked on the tested build

> **This is a free, open-source fan tool.** It is not affiliated with Reissad Studio, Steam, or UE4SS.
> Use it at your own risk. Granting yourself paid cosmetics may violate the game's terms of service.
> No bans have been observed during testing, but no guarantee is made. Do not sell this tool.

---

## What it unlocks

| Category | Examples |
| --- | --- |
| Operators | Operator Phantom, Snow Runner, Lima, France 02 … |
| Badges | Colonel S0, event and rank badges |
| Weapon skins | AK47 Case Hardened, Glock17 Ticket To Hell … |
| Attachments | MP5 forearms, sights, magazines, barrels, stocks |
| Stickers | Duck With A Knife, Skull Head Fire, UFO … |
| Flags | Every country flag in the shop |
| Charms / bundles | All shop bundles and charms |

The tool grants items that Steam has flagged as **promo items**. On the tested Bodycam build, the entire shop catalog is promo-eligible, so `GrantPromoItems` unlocks it in a single call.

It does **not** grant currency, XP, ELO, stats, battle-pass progress, or anything that is not a Steam inventory item.

---

## How it works

1. Waits for the game instance and the `DT_NewShopItem` data table to load.
2. Warms up for 15 seconds so Steam can finish loading your inventory.
3. Finds the game's own `SteamProInventory` class default object.
4. Calls `GrantPromoItems({})` once. Steam grants every eligible promo item.
5. Counts `HasPlayerUnlockedInventoryItem` across every shop row.
6. Writes the result to `unlock_status.txt` next to the mod scripts.

There are **no hooks, no memory patches, and no keybinds**. The mod does not modify game files; it only calls the same Steam/SteamCorePro API the game itself uses. If the first call does not unlock everything, it retries up to three times and then optionally falls back to `AddPromoItems` with the game's full item catalog.

---

## Requirements

- Windows 10 or 11 (64-bit)
- Bodycam on Steam (app ID **2406770**)
- Steam must be online and logged into the account you want to unlock
- **UE4SS** — the full bundle includes a tested copy; the mod-only package requires UE4SS already installed

---

## Installation

Two packages are published on the **Releases** page of this repository:

| Package | Use it if… |
| --- | --- |
| `Bodycam-Unlock-All-v1.0.0-full.zip` | You do **not** have UE4SS installed, or you want a tested all-in-one setup. |
| `Bodycam-Unlock-All-v1.0.0-mod.zip` | You already use UE4SS and other UE4SS mods. |

Close Bodycam before installing.

> If Bodycam is installed under `C:\Program Files` (or another protected folder), right-click `install.bat` and choose **Run as administrator**. Otherwise Windows may block the file copy.

### Option A — Full bundle (recommended for first-time users)

1. Download `Bodycam-Unlock-All-v1.0.0-full.zip` and extract it anywhere.
2. Double-click **`install.bat`**.
   - The installer finds Bodycam through Steam automatically.
   - If your game is in a custom location, run it from a terminal instead:
     ```bat
     install.bat -GamePath "D:\SteamLibrary\steamapps\common\Bodycam"
     ```
3. Start Bodycam and wait at the **main menu** for up to one minute.
4. The unlock finishes automatically. Check the status file:
   ```
   <Steam>\steamapps\common\Bodycam\Bodycam\Binaries\Win64\ue4ss\Mods\BodycamUnlockAll\Scripts\unlock_status.txt
   ```
   A successful run looks like this:
   ```
   Bodycam Unlock All v1.0.0
   Time: 2026-11-08 16:51:23
   Stage: ALREADY_UNLOCKED
   Owned: 2131/2131
   Missing: 0
   Method: none (already owned)
   ...
   ```
   On a fresh account the stage will be `GRANTED` instead.

The installer backs up `mods.txt` before changing it and never overwrites your existing UE4SS installation or other mods.

### Option B — Mod only (UE4SS already installed)

1. Download `Bodycam-Unlock-All-v1.0.0-mod.zip` and extract it anywhere.
2. Double-click **`install.bat`**.
3. If the installer reports that UE4SS was not found, install UE4SS first:
   <https://github.com/UE4SS-RE/RE-UE4SS/releases>
4. Start Bodycam and wait at the main menu.

### Manual installation

If you prefer to install by hand:

1. Copy the `BodycamUnlockAll` folder into:
   ```
   <Steam>\steamapps\common\Bodycam\Bodycam\Binaries\Win64\ue4ss\Mods\
   ```
2. Open `...\ue4ss\Mods\mods.txt` and add this line **before** the `; Built-in keybinds` comment:
   ```
   BodycamUnlockAll : 1
   ```
3. Restart Bodycam.

The mod folder also contains an empty `enabled.txt`, which tells UE4SS to load it.

---

## Verify it worked

1. Open `unlock_status.txt` at the path shown above. `Stage: GRANTED` or `Stage: ALREADY_UNLOCKED` with `Owned: 2131/2131` means success.
2. Open the in-game **Locker**. Every operator, weapon skin, sticker, flag and charm should be available.
3. Restart the game and check again. The items are permanent Steam inventory ownership and survive restarts.

The mod also writes `unlock_log.txt` with a timestamped trace of each stage. Both files are safe to delete; they are recreated on the next launch.

---

## Configuration

The mod works with no configuration. To change its behavior, edit:

```
...\BodycamUnlockAll\Scripts\config.lua
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `WARMUP_SECONDS` | `15` | Wait after the shop table loads before reading inventory. |
| `STARTUP_TIMEOUT_SECONDS` | `180` | Give up if the game never becomes ready. |
| `RETRIES` | `3` | Extra `GrantPromoItems` attempts after the first. |
| `RETRY_DELAY_SECONDS` | `30` | Delay between grant attempts. |
| `FALLBACK_ADDPROMOS` | `true` | Try `AddPromoItems` with the catalog if `GrantPromoItems` is not enough. |
| `FORCE_GRANT` | `false` | Always grant, even when everything is owned (testing only). |
| `WRITE_STATUS` | `true` | Write `unlock_status.txt` and `unlock_log.txt`. |
| `VERIFY_CHUNK` | `250` | Rows checked per tick. Lower is gentler but slower. |
| `TICK_MS` | `800` | Milliseconds between mod ticks. |

Delete `config.lua` to restore the defaults.

---

## Uninstalling

Run **`uninstall.bat`** from the package. It:

- removes `ue4ss\Mods\BodycamUnlockAll`
- removes the `BodycamUnlockAll : 1` line from `mods.txt` (with a timestamped backup)
- leaves UE4SS and any other mods untouched

**Already-granted items stay in your Steam inventory.** Removing the mod only stops future automatic unlocks; it does not revoke ownership. To remove UE4SS itself, follow the UE4SS documentation.

Manual uninstall: delete the `BodycamUnlockAll` folder and remove its line from `mods.txt`.

---

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| No `unlock_status.txt` appears | Confirm the mod folder is at `...\Win64\ue4ss\Mods\BodycamUnlockAll` and `BodycamUnlockAll : 1` is in `mods.txt`. Check `...\Win64\ue4ss\UE4SS.log` for lines beginning with `[BodycamUnlockAll]`. |
| `Stage: FAILED:game_not_ready` | The game did not create its game instance within 3 minutes. Launch again and wait at the main menu; check that UE4SS is loading at all. |
| `Stage: FAILED:no_datatable` | The game update moved or renamed `DT_NewShopItem`. Check for a newer release of this tool. |
| `Stage: FAILED:incomplete` | Make sure Steam is online and logged into the right account. Restart the game and try again. If it persists, attach `unlock_status.txt` and the last 50 lines of `UE4SS.log` to an issue. |
| `Stage: FAILED:verify_unavailable` | The UE4SS build does not expose the inventory check used by this tool. Try the UE4SS version from the full bundle. |
| The game crashes on startup after installing UE4SS | Remove `dwmapi.dll` and the `ue4ss` folder, then install the official UE4SS release. Conflicts with other injectors (ReShade, overlays) are possible. |
| Windows Defender flags `dwmapi.dll` | UE4SS is a DLL injector and is frequently false-positive flagged. Both release zips publish SHA-256 hashes. The mod-only package does not include the DLL. |
| Items do not appear in the locker | Restart the game after the grant. Make sure you are on the account that ran the tool; inventory is per Steam account. |

Need more detail? See [`INSTALL.md`](INSTALL.md).

---

## FAQ

**Is this real ownership?**
Yes. The tool uses Steam's promo-item API through the game's own `SteamCorePro` plugin. The items are attached to your Steam inventory and persist across game restarts and reinstalls. This is not a save editor or a visual spoof.

**Will it unlock future cosmetics automatically?**
Run the tool again after a game update. Any new item that Steam flags as a promo item will be granted. Items that are not promo-eligible cannot be granted this way.

**Does it give currency, XP, or stats?**
No. Only Steam inventory cosmetics.

**Can I get banned?**
No bans were observed during testing, but granting paid cosmetics may violate the game's terms of service. Use at your own risk. The tool does not bypass anti-cheat or modify game memory.

**Does it need to stay installed?**
No. After the grant, you can uninstall the mod. Ownership stays in your Steam inventory. Keeping it installed lets it re-run after updates.

**Does it work in offline mode?**
No. Steam must be online so the inventory service can grant the items.

**Does it modify game files?**
No. It adds a UE4SS Lua mod (and, in the full bundle, UE4SS itself). No `.pak`, `.exe`, or save files are changed.

**Why 2131 items?**
That is the number of rows in `DT_NewShopItem` on the tested build. The tool reports the actual row count it finds; a future game update may change it.

**Can I use it on several accounts?**
You can run it once per Steam account, but only on accounts you own. Do not use it to grant items to other people.

---

## Building from source

The repository contains the mod source, installers and release build script.

```
src/BodycamUnlockAll/       Lua mod (enabled.txt, Scripts/main.lua, Scripts/config.lua)
installer/                  install/uninstall PowerShell + batch wrappers
build/build-release.ps1     builds the mod-only and full zips + SHA-256
```

Requirements: Windows, PowerShell 5.1+, Bodycam + UE4SS for the full bundle.

```powershell
# From the repository root:
.\build\build-release.ps1

# Full bundle from a specific tested UE4SS installation:
.\build\build-release.ps1 -Ue4ssSource "C:\SteamLibrary\steamapps\common\Bodycam\Bodycam\Binaries\Win64"

# Mod-only package only:
.\build\build-release.ps1 -ModOnly
```

The script writes the zips, `SHA256.txt` and release notes to `dist/`.

---

## Tested on

| | |
| --- | --- |
| Game | Bodycam (Steam app 2406770), build current as of 2026-11-08 |
| UE4SS | v3.0.1 Beta #0, build `#83330635` (included in the full bundle) |
| OS | Windows 11 |
| Result | 2131 / 2131 shop rows owned, persisted after restart |

---

## Credits and license

- **Mod and installer:** MIT — see [`LICENSE`](LICENSE).
- **UE4SS:** MIT, © Narknon and contributors — see [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
- Bodycam and all game assets are property of Reissad Studio. This project ships no game assets and no Steamworks SDK code.

If this tool saved you a grind, consider supporting the game's developer by buying the cosmetics you enjoy — and never pay for this tool.
