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

function Disable-Mod {
    param([string]$ModsTxt, [string]$Name)

    if (-not (Test-Path -LiteralPath $ModsTxt)) {
        Write-Step 'mods.txt not found; nothing to clean up there.'
        return
    }

    $original = [System.IO.File]::ReadAllText($ModsTxt)
    $lines = @($original -split "\r?\n" | Where-Object { $_ -notmatch ('^\s*' + [regex]::Escape($Name) + '\s*:') })
    $newText = ($lines -join "`r`n")
    if (-not $newText.EndsWith("`r`n")) { $newText += "`r`n" }

    if ($newText -eq $original) {
        Write-Step "$Name was not listed in mods.txt"
        return
    }

    $backup = Get-BackupPath -Path $ModsTxt
    Copy-Item -LiteralPath $ModsTxt -Destination $backup -Force
    Write-Step "Backed up mods.txt to $(Split-Path -Leaf $backup)"
    [System.IO.File]::WriteAllText($ModsTxt, $newText, [System.Text.Encoding]::ASCII)
    Write-Step "Removed $Name from mods.txt"
}

# ---------------------------------------------------------------------------
# Locate the game
# ---------------------------------------------------------------------------

if (-not [string]::IsNullOrWhiteSpace($GamePath)) {
    $gameRoot = Resolve-GameRoot $GamePath
    if (-not $gameRoot) {
        Fail "Could not find Bodycam at or above '$GamePath'."
    }
} else {
    $gameRoot = Find-SteamGameRoot
    if (-not $gameRoot) {
        Fail 'Bodycam was not found in any Steam library. Run: uninstall.bat -GamePath "D:\path\to\Bodycam"'
    }
}

$win64 = Join-Path $gameRoot 'Bodycam\Binaries\Win64'
Write-Step "Game folder: $gameRoot"

# ---------------------------------------------------------------------------
# Remove the mod folder and its mods.txt entry
# ---------------------------------------------------------------------------

$candidateUe4ss = @(
    (Join-Path $win64 'ue4ss'),
    $win64
)

$removed = $false
foreach ($ue4ssDir in $candidateUe4ss) {
    $modsDir = Join-Path $ue4ssDir 'Mods'
    $destination = Join-Path $modsDir $ModName
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
        Write-Step "Removed $destination"
        $removed = $true
    }
    if (Test-Path -LiteralPath (Join-Path $modsDir 'mods.txt')) {
        Disable-Mod -ModsTxt (Join-Path $modsDir 'mods.txt') -Name $ModName
        $removed = $true
    }
}

if (-not $removed) {
    Write-Step 'No Bodycam Unlock All installation was found. Nothing to do.'
}

Write-Host ''
Write-Step 'Uninstalled. Already-granted items remain in your Steam inventory.'
Write-Step 'UE4SS and other mods were left untouched.'
Write-Host ''
