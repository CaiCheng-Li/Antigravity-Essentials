Write-Host "Installing Antigravity Essentials..." -ForegroundColor Cyan

$repoUrl = "https://github.com/CaiCheng-Li/Antigravity-Essentials.git"
$tempDir = Join-Path $env:TEMP "AgyEssentials"

# 1. Clone repository
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
Write-Host "Downloading scripts..."
git clone -q $repoUrl $tempDir

# 2. Copy scripts to home directory
Write-Host "Copying scripts to $env:USERPROFILE..."
Copy-Item "$tempDir\agy-*.ps1" $env:USERPROFILE -Force
Copy-Item "$tempDir\agy-*.cmd" $env:USERPROFILE -Force
Copy-Item "$tempDir\agy.bat" $env:USERPROFILE -Force
Copy-Item "$tempDir\cmd_autorun.cmd" $env:USERPROFILE -Force

# 3. Setup PowerShell Profile
Write-Host "Configuring PowerShell profile..."
$profileLine = ". `"$env:USERPROFILE\agy-wrapper.ps1`""
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -Type File -Force | Out-Null
}
$profileContent = Get-Content $PROFILE -Raw
if (-not ($profileContent -match "agy-wrapper.ps1")) {
    Add-Content -Path $PROFILE -Value "`n# Add custom agy flags (like --resume and --yolo)`n$profileLine"
}

# 4. Setup Command Prompt AutoRun
Write-Host "Configuring Command Prompt registry hook..."
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor" -Name "AutoRun" -Value '"%USERPROFILE%\cmd_autorun.cmd"' -Type ExpandString

# 5. Configure status line in settings.json
Write-Host "Enabling dynamic status line..."
$settingsPath = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\settings.json"
if (Test-Path $settingsPath) {
    try {
        $settingsJson = Get-Content $settingsPath -Raw
        $settings = $settingsJson | ConvertFrom-Json
        
        if ($null -eq $settings.statusLine) {
            $settings | Add-Member -Type NoteProperty -Name "statusLine" -Value @{}
        }
        
        $settings.statusLine.type = "command"
        $settings.statusLine.command = Join-Path $env:USERPROFILE "agy-statusline.cmd"
        $settings.statusLine.enabled = $true
        
        # Convert back to JSON and fix Unicode escaping
        $newJson = $settings | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($settingsPath, $newJson, [System.Text.Encoding]::UTF8)
    } catch {
        Write-Host "Could not automatically update settings.json. Please configure the statusLine manually." -ForegroundColor Yellow
    }
}

# Clean up
Remove-Item $tempDir -Recurse -Force

Write-Host "`nInstallation Complete! 🎉" -ForegroundColor Green
Write-Host "Please restart your terminal windows for all changes to take effect." -ForegroundColor Cyan
