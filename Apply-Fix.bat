@echo off
REM Double-click this to apply the STS2RobotSkinMod fix.
REM It just runs Apply-RobotSkinFix.ps1 with the execution policy bypassed for this one run.
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-RobotSkinFix.ps1"
echo.
pause
