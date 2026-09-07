@echo off
chcp 65001 >nul 2>&1
powershell -NoProfile -File "%~dp0agy-statusline.ps1"
