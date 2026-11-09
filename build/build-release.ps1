[CmdletBinding()]
param(
    [string]$Version = '',
    [string]$Ue4ssSource = '',
    [switch]$ModOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceMod = Join-Path $repoRoot 'src\BodycamUnlockAll'
$dist = Join-Path $repoRoot 'dist'
$staging = Join-Path $dist 'staging'

if (-not (Test-Path -LiteralPath $sourceMod)) {
    throw "Mod source not found: $sourceMod"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceMod 'Scripts\main.lua'))) {
    throw "main.lua not found under $sourceMod"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $mainLua = Get-Content -LiteralPath (Join-Path $sourceMod 'Scripts\main.lua') -Raw
    $match = [regex]::Match($mainLua, "local\s+VERSION\s*=\s*'([^']+)'")
    if (-not $match.Success) { throw 'Could not read VERSION from main.lua.' }
    $Version = $match.Groups[1].Value
}

Write-Host "[build] Bodycam Unlock All v$Version"

function Copy-CommonFiles {
    param([string]$Destination)
    Copy-Item -LiteralPath $sourceMod -Destination (Join-Path $Destination 'BodycamUnlockAll') -Recurse -Force
    foreach ($name in @('README.md', 'INSTALL.md', 'CHANGELOG.md', 'LICENSE', 'THIRD-PARTY-NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $Destination -Force
    }
    foreach ($name in @('install.bat', 'install.ps1', 'uninstall.bat', 'uninstall.ps1')) {
        Copy-Item -LiteralPath (Join-Path (Join-Path $repoRoot 'installer') $name) -Destination $Destination -Force
    }
}

function Resolve-Win64 {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $candidate = $Path.Trim().Trim('"').TrimEnd('\')
    if (Test-Path -LiteralPath (Join-Path $candidate 'ue4ss\UE4SS.dll')) { return $candidate }
    if ((Split-Path -Leaf $candidate) -ieq 'ue4ss' -and (Test-Path -LiteralPath (Join-Path $candidate 'UE4SS.dll'))) {
        return (Split-Path -Parent $candidate)
    }
    return $null
}

function New-Package {
    param([string]$Stage, [string]$FileName)
    $zipPath = Join-Path $dist $FileName
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "[build] Created $(Split-Path -Leaf $zipPath)"
    return $zipPath
}

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------

if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $staging 'mod') -Force | Out-Null

$modStage = Join-Path $staging 'mod'
Copy-CommonFiles -Destination $modStage
Write-Host "[build] Staged mod-only package"

$fullStage = $null
if (-not $ModOnly) {
    $win64 = Resolve-Win64 -Path $Ue4ssSource
    if ($null -eq $win64) {
        $defaultWin64 = 'C:\SteamLibrary\steamapps\common\Bodycam\Bodycam\Binaries\Win64'
        if (Test-Path -LiteralPath (Join-Path $defaultWin64 'ue4ss\UE4SS.dll')) {
            $win64 = $defaultWin64
        }
    }
    if ($null -eq $win64) {
        throw 'UE4SS source not found. Pass -Ue4ssSource "<...\Bodycam\Binaries\Win64>" (or -ModOnly to skip the full bundle).'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $win64 'dwmapi.dll'))) {
        throw "dwmapi.dll not found next to $win64. The full bundle needs the UE4SS injection proxy."
    }

    $fullStage = Join-Path $staging 'full'
    Copy-CommonFiles -Destination $fullStage

    $ue4ssDest = Join-Path $fullStage 'ue4ss'
    New-Item -ItemType Directory -Path $ue4ssDest -Force | Out-Null
    foreach ($name in @('UE4SS.dll', 'UE4SS-settings.ini', 'LICENSE')) {
        $source = Join-Path $win64 (Join-Path 'ue4ss' $name)
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Missing UE4SS file: $source"
        }
        Copy-Item -LiteralPath $source -Destination $ue4ssDest -Force
    }
    $sdkBackends = Join-Path $win64 'ue4ss\UE4SS_SDK_Backends'
    if (Test-Path -LiteralPath $sdkBackends) {
        Copy-Item -LiteralPath $sdkBackends -Destination $ue4ssDest -Recurse -Force
    }

    Copy-Item -LiteralPath (Join-Path $win64 'dwmapi.dll') -Destination $fullStage -Force

    $modsDest = Join-Path $ue4ssDest 'Mods'
    New-Item -ItemType Directory -Path $modsDest -Force | Out-Null
    Copy-Item -LiteralPath $sourceMod -Destination (Join-Path $modsDest 'BodycamUnlockAll') -Recurse -Force
    $modsTxt = "BodycamUnlockAll : 1`r`n`r`n; Built-in keybinds, do not move up!`r`nKeybinds : 1`r`n"
    [System.IO.File]::WriteAllText((Join-Path $modsDest 'mods.txt'), $modsTxt, [System.Text.Encoding]::ASCII)

    Write-Host "[build] Staged full bundle from $win64"
}

# ---------------------------------------------------------------------------
# Package + hashes
# ---------------------------------------------------------------------------

$zips = @()
$zips += New-Package -Stage $modStage -FileName "Bodycam-Unlock-All-v$Version-mod.zip"
if (-not $ModOnly -and $null -ne $fullStage) {
    $zips += New-Package -Stage $fullStage -FileName "Bodycam-Unlock-All-v$Version-full.zip"
}

$hashLines = @()
foreach ($zip in $zips) {
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashLines += "$hash  $(Split-Path -Leaf $zip)"
    Write-Host "[build] SHA256 $(Split-Path -Leaf $zip): $hash"
}
$hashFile = Join-Path $dist 'SHA256.txt'
[System.IO.File]::WriteAllText($hashFile, (($hashLines -join "`r`n") + "`r`n"), [System.Text.Encoding]::ASCII)
Write-Host "[build] Wrote $hashFile"

# ---------------------------------------------------------------------------
# Release notes skeleton
# ---------------------------------------------------------------------------

$downloadRows = @()
$downloadRows += "| ``Bodycam-Unlock-All-v$Version-full.zip`` | Recommended. Includes a tested UE4SS v3.0.1 Beta #0 installation. |"
$downloadRows += "| ``Bodycam-Unlock-All-v$Version-mod.zip`` | For users who already have UE4SS installed. |"

$downloadTable = $downloadRows -join "`r`n"
$hashTable = $hashLines -join "`r`n"
$notesTemplate = @'
# Bodycam Unlock All v{{VERSION}}

Unlocks every Bodycam shop cosmetic as real Steam inventory ownership.

## Downloads

| Package | Use it if... |
| --- | --- |
{{DOWNLOADS}}

## Install

1. Close Bodycam.
2. Extract the zip you downloaded.
3. Run `install.bat`.
4. Launch Bodycam and wait at the main menu for 30-60 seconds.
5. Check `ue4ss\Mods\BodycamUnlockAll\Scripts\unlock_status.txt`.

On the tested build the result is:

```
Stage: GRANTED
Owned: 2131/2131
Method: GrantPromoItems
```

## Checksums

See `SHA256.txt`:

```
{{HASHES}}
```

## Notes

- Real Steam inventory ownership; persists across restarts.
- No game files, saves or memory are modified.
- Cosmetics only; no currency, XP or stats.
- Free and open source. If someone charges you for this, you are being scammed.
- Not affiliated with Reissad Studio, Valve or UE4SS. Use at your own risk.

**Tested on:** Bodycam (Steam 2406770), UE4SS v3.0.1 Beta #0 (build #83330635), Windows 11.
'@

$notes = $notesTemplate.Replace('{{VERSION}}', $Version).Replace('{{DOWNLOADS}}', $downloadTable).Replace('{{HASHES}}', $hashTable)

$notesFile = Join-Path $dist "release-notes-v$Version.md"
[System.IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[build] Wrote $notesFile"

Write-Host ''
Write-Host '[build] Done.'
Write-Host "[build] Output folder: $dist"
