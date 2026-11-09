# Shipping checklist

This document is for the maintainer. It is **not** included in the release zips.

## 1. Final checks

- [ ] `dist\Bodycam-Unlock-All-v1.0.0-mod.zip` and `dist\Bodycam-Unlock-All-v1.0.0-full.zip` exist.
- [ ] `dist\SHA256.txt` matches both zips.
- [ ] Live test: normal launch reaches `Stage: ALREADY_UNLOCKED`, `Owned: 2131/2131`.
- [ ] Live test: forced grant reaches `Stage: GRANTED`, `Owned: 2131/2131`.
- [ ] Mod-only installer on a game without UE4SS fails with a clear message.
- [ ] Full-bundle installer on a clean game folder installs UE4SS and the mod.
- [ ] Installer works when the path contains spaces.
- [ ] Uninstaller removes the mod and its `mods.txt` line but leaves UE4SS intact.
- [ ] Second install does not duplicate the `mods.txt` line or create a new backup.

## 2. Publish the source

### Prerequisites

- Install **Git for Windows** if `git` is not available: <https://git-scm.com/download/win>
- Optional: install the **GitHub CLI** for command-line releases: <https://cli.github.com/>

Create an empty repository on GitHub first. A neutral name is recommended: `bodycam-unlock-all`.

```powershell
cd C:\Users\tyler\Documents\bodycam-unlock-all

git init
git config user.name "Your Name"
git config user.email "you@example.com"

git add .
git commit -m "Bodycam Unlock All v1.0.0"
git branch -M main

git remote add origin https://github.com/<your-account>/bodycam-unlock-all.git
git push -u origin main
```

The repository already includes:

- `README.md` and `INSTALL.md` for users
- `LICENSE` (MIT) and `THIRD-PARTY-NOTICES.md` (UE4SS attribution)
- `build/build-release.ps1` for reproducible packaging
- `.github/workflows/validate.yml` for Lua syntax checks and mod-only artifacts

## 3. Create the GitHub release

### Web UI

1. Open **Releases → Draft a new release**.
2. Tag: `v1.0.0`, target: `main`.
3. Title: `Bodycam Unlock All v1.0.0`.
4. Paste the contents of `dist/release-notes-v1.0.0.md`.
5. Attach:
   - `Bodycam-Unlock-All-v1.0.0-full.zip`
   - `Bodycam-Unlock-All-v1.0.0-mod.zip`
   - `SHA256.txt`
6. Publish the release.

### GitHub CLI

If `gh` is installed and authenticated:

```powershell
gh release create v1.0.0 `
  "dist/Bodycam-Unlock-All-v1.0.0-full.zip" `
  "dist/Bodycam-Unlock-All-v1.0.0-mod.zip" `
  "dist/SHA256.txt" `
  --title "Bodycam Unlock All v1.0.0" `
  --notes-file "dist/release-notes-v1.0.0.md"
```

If `gh` is not installed, use the web UI or install it from <https://cli.github.com/>.

## 4. Verify the published artifacts

1. Download both zips from the release page.
2. Compare their SHA-256 values with `SHA256.txt`:
   ```powershell
   Get-FileHash .\Bodycam-Unlock-All-v1.0.0-full.zip -Algorithm SHA256
   Get-FileHash .\Bodycam-Unlock-All-v1.0.0-mod.zip  -Algorithm SHA256
   ```
3. Extract the downloaded zips into empty folders and confirm the expected files exist.
4. Optionally run the full-bundle installer against a disposable test folder to confirm the published archive is intact.

## 5. Announce

- Link to the **release page**, not to a re-uploaded zip.
- Include the SHA-256 values if posting on a forum or Discord.
- Do not charge for the tool and do not bundle it with paid content.
- Ask users with problems to attach `unlock_status.txt` and the last 50 lines of `UE4SS.log`.

## 6. Version bumps

1. Update `VERSION` in `src\BodycamUnlockAll\Scripts\main.lua`.
2. Add an entry to `CHANGELOG.md`.
3. Run `build\build-release.ps1` (or `-ModOnly` for a Lua-only change that does not need a new UE4SS bundle).
4. Verify the new `dist\SHA256.txt`.
5. Tag `vX.Y.Z` and repeat the release steps.
