@echo off
setlocal enabledelayedexpansion

:: Check if any argument is --resume
set "is_resume=0"
for %%A in (%*) do (
    if "%%A"=="--resume" set "is_resume=1"
)

:: Translate --yolo to --dangerously-skip-permissions
set "ARGS=%*"
if not "!ARGS!"=="" (
    set "ARGS=!ARGS:--yolo=--dangerously-skip-permissions!"
)

if "!is_resume!"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\agy-resume.ps1" !ARGS!
) else (
    "%LOCALAPPDATA%\agy\bin\agy.exe" !ARGS!
)
