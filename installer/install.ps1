[CmdletBinding()]
param(
    [string]$GamePath = ''
)

$ErrorActionPreference = 'Stop'
$ModName = 'BodycamUnlockAll'
$ToolName = 'Bodycam Unlock All'

function Write-Step {
    param([string]$Message)
    Write-Host "[$ToolName] $Message"
}

function Fail {
    param([string]$Message)
    Write-Host "[$ToolName] ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Test-GameRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $candidate = Join-Path $Path 'Bodycam\Binaries\Win64\Bodycam-Win64-Shipping.exe'
    return (Test-Path -LiteralPath $candidate -PathType Leaf)
}

function Resolve-GameRoot {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $current = $Path.Trim().Trim('"').TrimEnd('\')
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        $current = Split-Path -Parent $current
    }
    for ($i = 0; $i -lt 8; $i++) {
        if (Test-GameRoot $current) { return $current }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return $null
}

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $keys = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )
    foreach ($key in $keys) {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($null -ne $props) {
            if ($props.SteamPath) { $roots.Add([string]$props.SteamPath) }
            if ($props.InstallPath) { $roots.Add([string]$props.InstallPath) }
        }
    }
    if (${env:ProgramFiles(x86)}) { $roots.Add((Join-Path ${env:ProgramFiles(x86)} 'Steam')) }
    if ($env:ProgramFiles) { $roots.Add((Join-Path $env:ProgramFiles 'Steam')) }
    return ($roots | Select-Object -Unique)
}

function Find-SteamGameRoot {
    foreach ($root in @(Get-SteamRoots)) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $steamRoot = $root.TrimEnd('\')
        $libraries = New-Object System.Collections.Generic.List[string]
        $libraries.Add($steamRoot)
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            $text = Get-Content -LiteralPath $vdf -Raw
            foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value -replace '\\\\', '\'
                $libraries.Add($library)
            }
        }
        foreach ($library in ($libraries | Select-Object -Unique)) {
            $candidate = Join-Path $library 'steamapps\common\Bodycam'
            if (Test-GameRoot $candidate) { return $candidate }
        }
    }
    return $null
}

function Copy-ModFiles {
    param([string]$Source, [string]$Destination)
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
    foreach ($file in (Get-ChildItem -LiteralPath $sourceFull -Recurse -File)) {
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $Destination $relative
        if ($relative -ieq 'Scripts\config.lua' -and (Test-Path -LiteralPath $target)) {
            Write-Step 'Keeping existing Scripts\config.lua'
            continue
        }
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
}

function Get-BackupPath {
    param([string]$Path)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $candidate = "$Path.$stamp.bak"
    $index = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = "$Path.$stamp-$index.bak"
        $index++
    }
    return $candidate
}

function Enable-Mod {
    param([string]$ModsTxt, [string]$Name)

    $exists = Test-Path -LiteralPath $ModsTxt
    $original = ''
    $lines = @()
    if ($exists) {
        $original = [System.IO.File]::ReadAllText($ModsTxt)
        $lines = @($original -split "\r?\n")
    }

    $updated = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($line in $lines) {
        if ($line -match ('^\s*' + [regex]::Escape($Name) + '\s*:')) { continue }
        if (-not $inserted -and $line -match '^\s*;\s*Built-in keybinds') {
            $updated.Add("$Name : 1")
            $inserted = $true
        }
        $updated.Add($line)
    }
    if (-not $inserted) { $updated.Add("$Name : 1") }
    while ($updated.Count -gt 0 -and [string]::IsNullOrWhiteSpace($updated[0])) {
        $updated.RemoveAt(0)
    }

    $newText = ($updated -join "`r`n")
    if (-not $newText.EndsWith("`r`n")) { $newText += "`r`n" }

    if ($newText -eq $original) {
        Write-Step "$Name is already enabled in mods.txt"
        return
    }

    if ($exists) {
        $backup = Get-BackupPath -Path $ModsTxt
        Copy-Item -LiteralPath $ModsTxt -Destination $backup -Force
        Write-Step "Backed up mods.txt to $(Split-Path -Leaf $backup)"
    }

    $parent = Split-Path -Parent $ModsTxt
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ModsTxt, $newText, [System.Text.Encoding]::ASCII)
    Write-Step "Enabled $Name in mods.txt"
}

# ---------------------------------------------------------------------------
# Locate the mod payload and the game
# ---------------------------------------------------------------------------

$sourceMod = Join-Path $PSScriptRoot 'BodycamUnlockAll'
if (-not (Test-Path -LiteralPath $sourceMod)) {
    $repoCandidate = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\BodycamUnlockAll'
    if (Test-Path -LiteralPath $repoCandidate) { $sourceMod = $repoCandidate }
}
if (-not (Test-Path -LiteralPath $sourceMod)) {
    Fail 'BodycamUnlockAll folder was not found next to this script. Extract the whole zip and try again.'
}

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $gameRoot = Resolve-GameRoot $GamePath
    if (-not $gameRoot) {
        Fail "Could not find Bodycam at or above '$GamePath'. Expected ...\Bodycam\Binaries\Win64\Bodycam-Win64-Shipping.exe."
    }
} else {
    $gameRoot = Find-SteamGameRoot
    if (-not $gameRoot) {
        Fail 'Bodycam was not found in any Steam library. Run: install.bat -GamePath "D:\path\to\Bodycam"'
    }
}

$win64 = Join-Path $gameRoot 'Bodycam\Binaries\Win64'
Write-Step "Game folder: $gameRoot"

# ---------------------------------------------------------------------------
# UE4SS: install the tested bundle only when UE4SS is not already present
# ---------------------------------------------------------------------------

$bundleUe4ss = Join-Path $PSScriptRoot 'ue4ss'
$hasBundledUe4ss = Test-Path -LiteralPath (Join-Path $bundleUe4ss 'UE4SS.dll')
$subfolderUe4ss = Join-Path $win64 'ue4ss'
$rootUe4ssDll = Join-Path $win64 'UE4SS.dll'

if ($hasBundledUe4ss -and -not (Test-Path -LiteralPath (Join-Path $subfolderUe4ss 'UE4SS.dll')) -and -not (Test-Path -LiteralPath $rootUe4ssDll)) {
    Write-Step 'UE4SS not found in the game folder; installing the tested bundle...'
    if (Test-Path -LiteralPath $subfolderUe4ss) {
        $backup = $subfolderUe4ss + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $subfolderUe4ss -Destination $backup
        Write-Step "Moved existing partial ue4ss folder to $(Split-Path -Leaf $backup)"
    }
    Copy-Item -LiteralPath $bundleUe4ss -Destination $subfolderUe4ss -Recurse -Force

    $bundleProxy = Join-Path $PSScriptRoot 'dwmapi.dll'
    $targetProxy = Join-Path $win64 'dwmapi.dll'
    if (Test-Path -LiteralPath $bundleProxy) {
        if (Test-Path -LiteralPath $targetProxy) {
            $bundleHash = (Get-FileHash -LiteralPath $bundleProxy -Algorithm SHA256).Hash
            $targetHash = (Get-FileHash -LiteralPath $targetProxy -Algorithm SHA256).Hash
            if ($bundleHash -ne $targetHash) {
                $proxyBackup = $targetProxy + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
                Copy-Item -LiteralPath $targetProxy -Destination $proxyBackup -Force
                Write-Step "Backed up existing dwmapi.dll to $(Split-Path -Leaf $proxyBackup)"
                Copy-Item -LiteralPath $bundleProxy -Destination $targetProxy -Force
            }
        } else {
            Copy-Item -LiteralPath $bundleProxy -Destination $targetProxy -Force
        }
    }
} elseif (Test-Path -LiteralPath (Join-Path $subfolderUe4ss 'UE4SS.dll')) {
    Write-Step 'UE4SS is already installed (ue4ss subfolder); leaving it untouched.'
} elseif (Test-Path -LiteralPath $rootUe4ssDll) {
    Write-Step 'UE4SS is already installed (game root layout); leaving it untouched.'
} else {
    Fail 'UE4SS was not found. Install UE4SS first, or use the full bundle package.'
}

# ---------------------------------------------------------------------------
# Locate the mods folder (supports both tested and UE4SS root layouts)
# ---------------------------------------------------------------------------

if (Test-Path -LiteralPath (Join-Path $subfolderUe4ss 'UE4SS.dll')) {
    $ue4ssDir = $subfolderUe4ss
} elseif (Test-Path -LiteralPath $rootUe4ssDll) {
    $ue4ssDir = $win64
} else {
    $ue4ssDir = $subfolderUe4ss
}
$modsDir = Join-Path $ue4ssDir 'Mods'
if (-not (Test-Path -LiteralPath $modsDir)) {
    New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Install the mod and enable it
# ---------------------------------------------------------------------------

$destination = Join-Path $modsDir $ModName
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-ModFiles -Source $sourceMod -Destination $destination
Write-Step "Installed mod files to $destination"

Enable-Mod -ModsTxt (Join-Path $modsDir 'mods.txt') -Name $ModName

Write-Host ''
Write-Step 'Done. Launch Bodycam and wait at the main menu for 30-60 seconds.'
Write-Step "Status file: $(Join-Path $destination 'Scripts\unlock_status.txt')"
Write-Host ''
