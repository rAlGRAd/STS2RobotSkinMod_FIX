<#
  Apply-RobotSkinFix.ps1
  Installs the fixed STS2RobotSkinMod (Defect robot skin) over your Steam Workshop copy.

  What it fixes:
    The mod's DLL calls Godot's ScriptManagerBridge.LookupScriptsInAssembly on its own
    assembly 3 times. That throws "An item with the same key has already been added" and
    aborts the mod's init (and breaks Defect combat visuals). This fix ships a DLL that
    makes that call exactly once, plus the matching PCK.

  What it does:
    - Auto-locates the Workshop folder for STS2RobotSkinMod (app 2868840, item 3747601919)
      across all your Steam library drives.
    - Refuses to run while the game is open.
    - Backs up the original files (.dll.bak / .pck.bak) the first time only.
    - Copies the fixed STS2RobotSkinMod.dll and .pck in, then verifies.
  Safe to re-run (e.g. after a Steam Workshop update reverts the files).
#>

[CmdletBinding()]
param(
  # Optional explicit path to the workshop item folder (…\2868840\3747601919). Auto-detected if omitted.
  [string]$WorkshopDir
)
$ErrorActionPreference = 'Stop'
$AppId  = '2868840'
$ItemId = '3747601919'
$here   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Find-SteamRoot {
  foreach ($k in 'HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam') {
    try {
      $p = (Get-ItemProperty -Path $k -ErrorAction Stop)
      $v = $p.SteamPath; if (-not $v) { $v = $p.InstallPath }
      if ($v -and (Test-Path $v)) { return ($v -replace '/', '\') }
    } catch {}
  }
  return $null
}

function Get-LibraryRoots {
  $roots = New-Object System.Collections.Generic.List[string]
  $steam = Find-SteamRoot
  if ($steam) {
    $roots.Add($steam)
    foreach ($vdf in @("$steam\steamapps\libraryfolders.vdf","$steam\config\libraryfolders.vdf")) {
      if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
          $roots.Add(($m.Groups[1].Value -replace '\\\\','\'))
        }
      }
    }
  }
  # common fallbacks
  foreach ($d in 'C','D','E','F','G','H') {
    $roots.Add("$d`:\SteamLibrary"); $roots.Add("$d`:\Steam"); $roots.Add("$d`:\Program Files (x86)\Steam")
  }
  $roots | Where-Object { $_ } | Select-Object -Unique
}

function Resolve-WorkshopDir {
  if ($WorkshopDir -and (Test-Path (Join-Path $WorkshopDir 'STS2RobotSkinMod.dll'))) { return $WorkshopDir }
  foreach ($r in Get-LibraryRoots) {
    $cand = Join-Path $r "steamapps\workshop\content\$AppId\$ItemId"
    if (Test-Path (Join-Path $cand 'STS2RobotSkinMod.dll')) { return $cand }
  }
  return $null
}

# --- locate ---
$dir = Resolve-WorkshopDir
if (-not $dir) {
  Write-Host "ERROR: Could not find STS2RobotSkinMod in any Steam library." -ForegroundColor Red
  Write-Host "Make sure you're subscribed to it on the Workshop and have launched the game once."
  Write-Host "Then re-run, optionally passing the path explicitly:"
  Write-Host '  powershell -ExecutionPolicy Bypass -File Apply-RobotSkinFix.ps1 -WorkshopDir "X:\...\2868840\3747601919"'
  exit 1
}
Write-Host "Found mod at: $dir"

# --- game must be closed ---
if (Get-Process -Name 'SlayTheSpire2' -ErrorAction SilentlyContinue) {
  Write-Host "ERROR: Slay the Spire 2 is running. Close it fully, then re-run." -ForegroundColor Red
  exit 1
}

# --- fixed payload present? ---
$srcDll = Join-Path $here 'STS2RobotSkinMod.dll'
$srcPck = Join-Path $here 'STS2RobotSkinMod.pck'
foreach ($f in @($srcDll,$srcPck)) {
  if (-not (Test-Path $f)) { Write-Host "ERROR: missing bundled file: $f" -ForegroundColor Red; exit 1 }
}

# --- apply (backup-once, copy, verify) ---
$pairs = @(
  @{ name='STS2RobotSkinMod.dll'; src=$srcDll },
  @{ name='STS2RobotSkinMod.pck'; src=$srcPck }
)
foreach ($p in $pairs) {
  $dst = Join-Path $dir $p.name
  $bak = "$dst.bak"
  try { $h=[IO.File]::Open($dst,'Open','ReadWrite','None'); $h.Close() }
  catch { Write-Host "ERROR: '$($p.name)' is locked (game open?)." -ForegroundColor Red; exit 1 }
  if ((Test-Path $dst) -and -not (Test-Path $bak)) { Copy-Item $dst $bak; Write-Host "  backed up original -> $($p.name).bak" }
  Copy-Item $p.src $dst -Force
  $ok = ((Get-Item $dst).Length -eq (Get-Item $p.src).Length)
  Write-Host ("  installed {0} ({1:N0} bytes) verified={2}" -f $p.name,(Get-Item $dst).Length,$ok)
  if (-not $ok) { Write-Host "ERROR: size mismatch after copy." -ForegroundColor Red; exit 1 }
}

# --- sanity: exactly one LookupScriptsInAssembly call (28 27 00 00 0a) in the DLL ---
$b = [IO.File]::ReadAllBytes((Join-Path $dir 'STS2RobotSkinMod.dll'))
$n = 0; for ($i=0; $i -lt $b.Length-4; $i++) { if ($b[$i] -eq 0x28 -and $b[$i+1] -eq 0x27 -and $b[$i+2] -eq 0 -and $b[$i+3] -eq 0 -and $b[$i+4] -eq 0x0a) { $n++ } }
Write-Host "  DLL registration-call count = $n (expected 1)"

Write-Host ""
if ($n -eq 1) { Write-Host "SUCCESS - launch the game and pick Defect. To revert: restore the .bak files." -ForegroundColor Green }
else { Write-Host "WARNING: unexpected DLL state; the bundled DLL may not match. Restore .bak if anything looks off." -ForegroundColor Yellow }
Write-Host "Note: a Steam Workshop update or 'Verify integrity of game files' will revert this - just re-run me."
