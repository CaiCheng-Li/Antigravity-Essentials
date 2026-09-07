# Setup script for agy-statusline
# This script configures the Antigravity CLI to show usage bars below the prompt.

$settingsPath = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\settings.json"

if (-not (Test-Path $settingsPath)) {
    Write-Host "ERROR: settings.json not found at $settingsPath" -ForegroundColor Red
    exit 1
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Build the command string with proper escaping for the path
$scriptPath = Join-Path $env:USERPROFILE "agy-statusline.ps1"
$command = "powershell -NoProfile -File `"$scriptPath`""

# Add statusLine configuration
$statusLine = [PSCustomObject]@{
    type              = "command"
    command           = $command
    enabled           = $true
    stack_with_default = $false
}

# Add or update the statusLine property
if ($settings.PSObject.Properties['statusLine']) {
    $settings.statusLine = $statusLine
} else {
    $settings | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $statusLine
}

# Write back (without BOM — Go's JSON parser chokes on the UTF-8 BOM)
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "  Status line configured successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  Script: $scriptPath" -ForegroundColor Cyan
Write-Host "  Config: $settingsPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Restart agy to see the usage bars below the prompt." -ForegroundColor Yellow
Write-Host ""
