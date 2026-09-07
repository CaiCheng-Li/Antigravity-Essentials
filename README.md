# Antigravity Essentials

A collection of power-user enhancements and scripts for the Google Antigravity CLI (`agy`), focusing on quality-of-life terminal UI improvements.

## Features

### 1. Interactive Resume (`--resume`)
Tired of scrolling through logs to find a conversation ID? The `--resume` flag adds a sleek, arrow-key navigable Terminal User Interface (TUI) directly inside your terminal. It filters conversations to your current working directory and displays a snippet of your original prompt so you can easily pick up where you left off.

<img width="947" height="328" alt="Screenshot 2026-09-07 010903" src="https://github.com/user-attachments/assets/8e07c8b0-4938-4a52-b8ae-38a70787424b" />

### 2. Dynamic Model-Aware Status Line
The default Antigravity status line script has been upgraded to be contextually aware of your active AI model. When you use `/model` to switch between Gemini and Claude/GPT, the usage bars at the bottom of your screen instantly adapt, filtering out irrelevant rate limits and showing you exactly the quota buckets that matter for your current session.

<img width="511" height="155" alt="Screenshot 2026-09-07 011134" src="https://github.com/user-attachments/assets/24c7c975-af71-49a9-ab73-314744e0108f" /> <img width="451" height="146" alt="Screenshot 2026-09-07 011151" src="https://github.com/user-attachments/assets/deea2bbc-8a72-4194-94b9-8b9fa58317e4" />

---

## Installation

Download or clone all the scripts in this repository to your home folder (`%USERPROFILE%`), for example `C:\Users\YourName\`.

### Setting up the Status Line

1. Open your Antigravity CLI settings file located at `~/.gemini/antigravity-cli/settings.json`.
2. Add or update the `statusLine` configuration to point to the `agy-statusline.cmd` wrapper:
   ```json
   "statusLine": {
     "type": "command",
     "command": "C:\\Users\\YourName\\agy-statusline.cmd",
     "enabled": true
   }
   ```
*(Note: Replace `YourName` with your actual Windows username folder).*

### Setting up the `--resume` flag

Because `agy` is a compiled binary, we intercept the command using a lightweight shell wrapper that handles the `--resume` flag before passing everything else cleanly to the native application.

#### For PowerShell Users

Add the following to your PowerShell profile. You can open your profile by running `notepad $PROFILE` in PowerShell:

```powershell
# Add custom agy flags (like --resume)
. "$env:USERPROFILE\agy-wrapper.ps1"
```

#### For Command Prompt (CMD) Users

To make the wrapper work globally in `cmd.exe`, we use a `doskey` macro loaded via the Command Processor AutoRun registry key.

1. Ensure `cmd_autorun.cmd` and `agy.bat` are in your home folder.
2. Open PowerShell or CMD as an administrator and run:
   ```powershell
   Set-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor" -Name "AutoRun" -Value '"%USERPROFILE%\cmd_autorun.cmd"' -Type ExpandString
   ```
*(Note: If you already have an AutoRun script configured for CMD, simply copy the `doskey` line from `cmd_autorun.cmd` into your existing script).*

## Usage

Simply run:
```bash
agy --resume
```
You can also chain native flags together! For example:
```bash
agy --dangerously-skip-permissions --resume
```
