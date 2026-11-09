# Changelog

All notable changes to Bodycam Unlock All are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-11-08

### Added

- Automatic unlock of every Bodycam shop cosmetic as real Steam inventory ownership.
- Single-call `GrantPromoItems` implementation via the game's `SteamProInventory` class default object.
- Ownership verification over every `DT_NewShopItem` row.
- `unlock_status.txt` and `unlock_log.txt` reports with stage, counts, method and errors.
- Automatic retries and an optional `AddPromoItems` fallback.
- `config.lua` for warm-up, timeouts, retries, verification and logging.
- Full-bundle package with a tested UE4SS v3.0.1 Beta #0 (`#83330635`) installation.
- Mod-only package for users who already run UE4SS.
- `install.bat` / `uninstall.bat` with Steam library detection, `mods.txt` backups and idempotent updates.
- README, installation guide, third-party notices and SHA-256 checksums.

### Verified

- 2131 / 2131 shop rows owned on a fresh grant.
- Ownership persisted after a full game and Steam restart.
- `ALREADY_UNLOCKED` path verified on subsequent launches.
- `GRANTED` path re-verified by forcing a grant on a complete inventory.
