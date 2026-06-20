# STS2RobotSkinMod — crash fix (Defect robot skin)

Fixes the Steam Workshop mod **STS2RobotSkinMod** (item `3747601919`) for **Slay the Spire 2**,
which crashes on load and breaks the Defect in combat.

[![Download the installer](https://img.shields.io/badge/Download-Installer%20(.exe)-2ea44f?style=for-the-badge&logo=windows)](https://github.com/rAlGRAd/-STS2RobotSkinMod_FIX/releases/latest/download/STS2RobotSkinMod-fix-Installer.exe)
[![Download the .zip](https://img.shields.io/badge/Download-.zip-555555?style=for-the-badge)](https://github.com/rAlGRAd/-STS2RobotSkinMod_FIX/releases/latest/download/STS2RobotSkinMod-fix.zip)

> **Quick install:** download the installer above → fully close Slay the Spire 2 → run it.
> It's unsigned, so SmartScreen will warn — click **More info → Run anyway**.

## The problem
On launch the mod logs:

```
[Error] [STS2RobotSkinMod] Initialize failed: An item with the same key has already been added.
Key: res://STS2RobotSkinModCode/Node/Dummy/NCreatureVisualsDummy.cs
  at Godot.Bridge.ScriptManagerBridge.PathScriptTypeBiMap.Add(...)
  at STS2RobotSkinMod.STS2RobotSkinModMain.Initialize()
```

…and if you reach combat as Defect:

```
[Error] [STS2RobotSkinMod] CreateVisuals patch exception:
Unable to cast object of type 'Godot.Node2D' to type 'NCreatureVisuals'.
```

**Cause:** the mod's DLL calls `ScriptManagerBridge.LookupScriptsInAssembly` on its *own*
assembly **three times**. That call is what registers the mod's scripts so its scenes can
instantiate — but calling it more than once throws a duplicate-key exception and aborts init.

**Fix:** a DLL where that call happens **exactly once** (the two redundant calls are NOP'd out,
in place — same size, no other change), plus the matching PCK. Confirmed working: the skin loads
and a full Defect run plays cleanly.

## Install (easy)
1. **Subscribe** to STS2RobotSkinMod on the Workshop and launch the game once (so Steam downloads it).
2. **Fully close** Slay the Spire 2.
3. Double-click **`Apply-Fix.bat`**.

It finds the mod in any of your Steam libraries, backs up the originals, and installs the fix.

## Install (manual)
Copy `STS2RobotSkinMod.dll` and `STS2RobotSkinMod.pck` from this folder over the ones in:

```
<your Steam library>\steamapps\workshop\content\2868840\3747601919\
```

(Back up the originals first if you like.)

## Revert
Restore the `.dll.bak` / `.pck.bak` files the installer created (delete the `.bak` suffix), or
just unsubscribe + resubscribe to let Steam redownload the originals.

## Heads-up
A Workshop **update** to the mod, or Steam's **"Verify integrity of game files,"** will overwrite
these files with the broken originals again. If the crash comes back, just run `Apply-Fix.bat`
again.

## Permanent fix
This is a workaround. The real fix is for the mod author to remove the redundant
`LookupScriptsInAssembly` calls and recompile. Report:

> `STS2RobotSkinModMain.Initialize()` (and two other methods) each call
> `ScriptManagerBridge.LookupScriptsInAssembly` on the mod's own assembly. That call must run
> exactly once to register the scripts; running it more than once throws a duplicate-key
> exception (`PathScriptTypeBiMap.Add`) and aborts init. Remove the redundant calls so it runs once.

## Files
- `STS2RobotSkinMod.dll` — patched (one registration call instead of three)
- `STS2RobotSkinMod.pck` — matching pack
- `Apply-RobotSkinFix.ps1` — installer (auto-locates Workshop folder, backs up, installs, verifies)
- `Apply-Fix.bat` — double-click wrapper for the installer
