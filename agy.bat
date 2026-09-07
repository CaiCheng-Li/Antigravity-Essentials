@echo off
setlocal enabledelayedexpansion

:: Check if any argument is --resume
set "is_resume=0"
for %%A in (%*) do (
    if "%%A"=="--resume" set "is_resume=1"
)

if "!is_resume!"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\agy-resume.ps1" %*
) else (
    "%LOCALAPPDATA%\agy\bin\agy.exe" %*
)
