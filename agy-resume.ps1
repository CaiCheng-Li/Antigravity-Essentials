<#
.SYNOPSIS
    agy --resume: Interactive conversation picker for the current directory.

.DESCRIPTION
    Reads the Antigravity CLI history.jsonl, filters conversations that belong
    to the current working directory, shows an interactive numbered list with
    timestamps and first-prompt summaries, and resumes the selected conversation
    via `agy --conversation <id>`.

    Usage:  agy --resume [extra agy flags...]
    Example: agy --resume --dangerously-skip-permissions
#>

[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$ExtraArgs
)

# ── Configuration ─────────────────────────────────────────────────────────────
$AgyDataDir  = [System.IO.Path]::Combine($env:USERPROFILE, ".gemini", "antigravity-cli")
$HistoryFile = [System.IO.Path]::Combine($AgyDataDir, "history.jsonl")
$BrainDir    = [System.IO.Path]::Combine($AgyDataDir, "brain")

# ANSI escape sequences
$E     = [char]0x1B
$Bold  = "$E[1m"
$Dim   = "$E[2m"
$Reset = "$E[0m"
$Cyan  = "$E[96m"
$Green = "$E[92m"
$Yellow = "$E[93m"
$Magenta = "$E[95m"
$Gray  = "$E[90m"
$White = "$E[97m"

# ── Validate history file ────────────────────────────────────────────────────
if (-not (Test-Path $HistoryFile)) {
    Write-Host "${Yellow}No conversation history found.${Reset}" -NoNewline
    Write-Host " Start a conversation first with ${Cyan}agy${Reset}."
    exit 1
}

# ── Read and filter history ──────────────────────────────────────────────────
$currentDir = (Get-Location).Path

# Parse history entries
$entries = Get-Content $HistoryFile -Encoding UTF8 | Where-Object { $_.Trim() -ne "" } | ForEach-Object {
    try { $_ | ConvertFrom-Json } catch { $null }
} | Where-Object { $_ -ne $null }

# Filter to entries that have a conversationId and match the current workspace
$filtered = $entries | Where-Object {
    $_.conversationId -and $_.workspace -and
    ($_.workspace.TrimEnd('\','/') -eq $currentDir.TrimEnd('\','/'))
}

if (-not $filtered -or @($filtered).Count -eq 0) {
    Write-Host "${Yellow}No conversations found for this directory:${Reset}"
    Write-Host "  ${Dim}$currentDir${Reset}"
    Write-Host ""
    Write-Host "Conversations are matched by workspace. Run ${Cyan}agy${Reset} from this directory to start one."
    exit 1
}

# ── Build conversation list (deduplicate by conversationId) ──────────────────
# Group entries by conversationId, extract summary info from each group
$convGroups = @{}
foreach ($entry in $filtered) {
    $cid = $entry.conversationId
    if (-not $convGroups.ContainsKey($cid)) {
        $convGroups[$cid] = @{
            Id              = $cid
            FirstTimestamp  = $entry.timestamp
            LastTimestamp   = $entry.timestamp
            FirstPrompt     = $null
            PromptCount     = 0
        }
    }

    $group = $convGroups[$cid]

    # Track timestamps
    if ($entry.timestamp -lt $group.FirstTimestamp) {
        $group.FirstTimestamp = $entry.timestamp
    }
    if ($entry.timestamp -gt $group.LastTimestamp) {
        $group.LastTimestamp = $entry.timestamp
    }

    # Count user prompts (exclude slash commands)
    $isSlash = ($entry.type -eq "slash_command")
    if (-not $isSlash -and $entry.display) {
        $group.PromptCount++
        if (-not $group.FirstPrompt) {
            $group.FirstPrompt = $entry.display
        }
    }
}

# Also try to extract the first user prompt from transcripts for conversations
# that only had slash commands in history
foreach ($cid in @($convGroups.Keys)) {
    $group = $convGroups[$cid]
    if (-not $group.FirstPrompt) {
        $transcriptFile = [System.IO.Path]::Combine($BrainDir, $cid, ".system_generated", "logs", "transcript.jsonl")
        if (Test-Path $transcriptFile) {
            $lines = Get-Content $transcriptFile -TotalCount 5 -Encoding UTF8
            foreach ($line in $lines) {
                if ($line.Trim() -eq "") { continue }
                try {
                    $step = $line | ConvertFrom-Json
                    if ($step.type -eq "USER_INPUT" -and $step.content) {
                        # Extract from <USER_REQUEST> tags
                        if ($step.content -match '<USER_REQUEST>\s*(.*?)\s*</USER_REQUEST>') {
                            $group.FirstPrompt = $Matches[1].Trim()
                            break
                        }
                    }
                } catch {}
            }
        }
    }
}

# Sort conversations by last activity (most recent first)
$sortedConvs = $convGroups.Values | Sort-Object { $_.LastTimestamp } -Descending

# ── Pre-format menu items ────────────────────────────────────────────────────
$menuItems = @()
foreach ($conv in $sortedConvs) {
    $ts = [DateTimeOffset]::FromUnixTimeMilliseconds($conv.LastTimestamp).LocalDateTime.ToString("yyyy-MM-dd HH:mm")
    $summary = if ($conv.FirstPrompt) {
        $s = $conv.FirstPrompt -replace '[\r\n]+', ' '
        if ($s.Length -gt 60) { $s.Substring(0, 57) + "..." } else { $s }
    } else {
        "[no prompt text]"
    }
    $promptInfo = if ($conv.PromptCount -gt 0) { "$($conv.PromptCount) msgs" } else { "" }
    $shortId = $conv.Id.Substring(0, 8)
    
    $menuItems += @{
        Id = $conv.Id
        ShortId = $shortId
        Time = $ts
        Summary = $summary
        Info = $promptInfo
    }
}

# ── Display interactive picker ───────────────────────────────────────────────
$selectedIndex = 0
$linesPrinted = 0
$needsRedraw = $true

function Out-Line($text) {
    Write-Host $text
    $script:linesPrinted++
}

while ($true) {
    if ($needsRedraw) {
        [Console]::CursorVisible = $false
        
        if ($linesPrinted -gt 0) {
            # Move cursor up and clear to end of screen
            [Console]::Write("$E[${linesPrinted}A$E[0J")
        }
        $script:linesPrinted = 0
        
        Out-Line ""
        Out-Line "${Bold}${Cyan}  Conversations in ${White}$currentDir${Reset}"
        Out-Line "${Dim}  -------------------------------------------------------------${Reset}"
        Out-Line ""
        
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $item = $menuItems[$i]
            
            # Colors based on selection
            if ($i -eq $selectedIndex) {
                $indicator = "${Bold}${Cyan}>${Reset}"
                $timeColor = "${White}"
                $idColor   = "${White}"
                $sumColor  = "${Cyan}"
                $infoColor = "${Dim}${Cyan}"
            } else {
                $indicator = " "
                $timeColor = "${Dim}"
                $idColor   = "${Gray}"
                $sumColor  = "${Reset}"
                $infoColor = "${Dim}"
            }
            
            Out-Line "  $indicator  ${timeColor}$($item.Time)${Reset}  ${idColor}$($item.ShortId)${Reset}  ${sumColor}$($item.Summary)${Reset}"
            
            if ($item.Info) {
                Out-Line "        ${infoColor}$($item.Info)${Reset}"
            }
        }
        
        Out-Line ""
        Out-Line "${Dim}  -------------------------------------------------------------${Reset}"
        Out-Line "  ${Dim}Use Up/Down arrows to select, Enter to confirm, Esc/Q to quit.${Reset}"
        
        $needsRedraw = $false
    }
    
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq 'UpArrow' -and $selectedIndex -gt 0) {
        $selectedIndex--
        $needsRedraw = $true
    } elseif ($key.Key -eq 'DownArrow' -and $selectedIndex -lt ($menuItems.Count - 1)) {
        $selectedIndex++
        $needsRedraw = $true
    } elseif ($key.Key -eq 'Enter') {
        break
    } elseif ($key.Key -eq 'Escape' -or $key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
        [Console]::CursorVisible = $true
        Write-Host ""
        Write-Host "  ${Dim}Cancelled.${Reset}"
        exit 0
    }
}

[Console]::CursorVisible = $true
$selectedId = $menuItems[$selectedIndex].Id

Write-Host ""
Write-Host "  ${Cyan}Resuming conversation ${White}$($selectedId.Substring(0,8))...${Reset}"
Write-Host ""

# ── Launch agy with the selected conversation ────────────────────────────────
$agyArgs = @("--conversation", $selectedId)
if ($ExtraArgs) {
    # Strip out --resume (and any other wrapper-specific flags)
    $filteredArgs = $ExtraArgs | Where-Object { $_ -ne '--resume' }
    if ($filteredArgs) {
        $agyArgs += $filteredArgs
    }
}

$agyExe = [System.IO.Path]::Combine($env:LOCALAPPDATA, "agy", "bin", "agy.exe")
if (-not (Test-Path $agyExe)) {
    $agyExe = (Get-Command agy.exe -ErrorAction SilentlyContinue).Source
}
if ($agyExe) {
    & $agyExe @agyArgs
} else {
    Write-Host "Error: agy.exe not found" -ForegroundColor Red
}
