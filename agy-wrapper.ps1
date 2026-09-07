# ── Antigravity CLI Wrapper ───────────────────────────────────────────────────
# Wraps the native `agy` command to add custom flags like --resume.
# Source this in your PowerShell profile, or dot-source it: . ~\agy-wrapper.ps1

function agy {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    # Check if --resume is in the arguments
    if ($Arguments -contains '--resume') {
        # Remove --resume from the args and pass the rest to agy-resume.ps1
        $remaining = $Arguments | Where-Object { $_ -ne '--resume' }
        $script = Join-Path $env:USERPROFILE "agy-resume.ps1"
        if (Test-Path $script) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script @remaining
        } else {
            Write-Host "Error: agy-resume.ps1 not found at $script" -ForegroundColor Red
        }
        return
    }

    # Otherwise, pass through to the real agy binary
    $agyExe = Join-Path $env:LOCALAPPDATA "agy" "bin" "agy.exe"
    if (-not (Test-Path $agyExe)) {
        # Fallback: find it on PATH
        $agyExe = (Get-Command agy.exe -ErrorAction SilentlyContinue).Source
    }
    if ($agyExe) {
        & $agyExe @Arguments
    } else {
        Write-Host "Error: agy.exe not found" -ForegroundColor Red
    }
}
