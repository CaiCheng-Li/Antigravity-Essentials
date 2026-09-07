[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Antigravity CLI Status Line — Compact Usage Bars
# Renders context window + rate limit bars with ANSI colors below the prompt.
# Bars and accent color adapt to the active model.
# Design reference: https://github.com/CaiCheng-Li/Codex-TerminalBar

# Read JSON payload from stdin
$inputJson = [System.Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputJson)) { exit 0 }

try {
    $data = $inputJson | ConvertFrom-Json
} catch {
    exit 0
}

# ── ANSI escape sequences ────────────────────────────────────────────────────
$E = [char]0x1B

# ── Model detection & theming ─────────────────────────────────────────────────
$modelId   = ""
$modelName = ""
if ($null -ne $data.model) {
    if ($null -ne $data.model.id)           { $modelId   = $data.model.id.ToLower() }
    if ($null -ne $data.model.display_name) { $modelName = $data.model.display_name }
    elseif ($null -ne $data.model.id)       { $modelName = $data.model.id }
}

# Pick an accent color based on model family
# Gemini = blue, Claude = magenta, GPT = cyan, default = white
$accentColor = switch -Wildcard ($modelId) {
    '*gemini*'  { "$E[94m"  }   # bright blue
    '*claude*'  { "$E[95m"  }   # bright magenta
    '*gpt*'     { "$E[96m"  }   # bright cyan
    '*o1*'      { "$E[96m"  }   # bright cyan
    '*o3*'      { "$E[96m"  }   # bright cyan
    '*o4*'      { "$E[96m"  }   # bright cyan
    '*llama*'   { "$E[94m"  }   # bright blue
    '*mistral*' { "$E[33m"  }   # orange/yellow
    default     { "$E[97m"  }   # bright white
}

# Pick bar fill color per model (low-usage state)
$barFillLow = switch -Wildcard ($modelId) {
    '*gemini*'  { "$E[94m"  }   # blue
    '*claude*'  { "$E[95m"  }   # magenta
    '*gpt*'     { "$E[96m"  }   # cyan
    '*o1*'      { "$E[96m"  }
    '*o3*'      { "$E[96m"  }
    '*o4*'      { "$E[96m"  }
    default     { "$E[92m"  }   # green
}

# ── Bar rendering ─────────────────────────────────────────────────────────────
function Render-Bar {
    param(
        [string]$Label,
        [double]$Pct,
        [string]$Suffix = "",
        [int]$BarWidth = 20
    )

    $Pct = [Math]::Max(0, [Math]::Min(100, $Pct))
    $filled = [int][Math]::Floor($BarWidth * $Pct / 100)
    $empty  = $BarWidth - $filled

    # Color thresholds: model accent < 70%, yellow 70-89%, red >= 90%
    if ($Pct -ge 90) {
        $fillColor = "$E[91m"     # bright red
        $pctColor  = "$E[91m"
    } elseif ($Pct -ge 70) {
        $fillColor = "$E[93m"     # bright yellow
        $pctColor  = "$E[93m"
    } else {
        $fillColor = $script:barFillLow
        $pctColor  = $script:barFillLow
    }

    $dim   = "$E[2m"
    $reset = "$E[0m"
    $gray  = "$E[90m"

    # Bar character: ▬ (U+25AC)
    $barChar = [char]0x25AC
    $filledStr = $fillColor + ([string]$barChar * $filled) + $reset
    $emptyStr  = $gray + ([string]$barChar * $empty) + $reset

    # Format percentage right-aligned
    $pctStr = $pctColor + ("{0,5:N1}%" -f $Pct) + $reset

    # Label (dimmed, fixed width)
    $paddedLabel = $Label.PadRight(6)
    $labelStr = $dim + $paddedLabel + $reset

    $line = "$labelStr $filledStr$emptyStr $pctStr"
    if ($Suffix) {
        $line += " $dim$Suffix$reset"
    }
    return $line
}

# ── Countdown formatter ───────────────────────────────────────────────────────
function Format-Countdown([double]$Seconds) {
    if ($Seconds -le 0) { return "" }
    $h = [int][Math]::Floor($Seconds / 3600)
    $m = [int][Math]::Floor(($Seconds % 3600) / 60)
    return "{0}:{1:D2}" -f $h, $m
}

# ── Collect bars ──────────────────────────────────────────────────────────────
$dim   = "$E[2m"
$reset = "$E[0m"
$lines = @()

# Model name header
if ($modelName) {
    $lines += "$accentColor$modelName$reset"
}

# 1) Context Window bar
$ctx = $data.context_window
if ($null -ne $ctx -and $null -ne $ctx.used_percentage) {
    $usedPct = [double]$ctx.used_percentage

    $suffix = ""
    $totalTokens = if ($null -ne $ctx.context_window_size) { [long]$ctx.context_window_size } else { 0 }
    $usedTokens  = if ($null -ne $ctx.total_input_tokens)  { [long]$ctx.total_input_tokens  } else { 0 }

    if ($totalTokens -gt 0) {
        $usedK  = [Math]::Round($usedTokens / 1000)
        $totalK = [Math]::Round($totalTokens / 1000)
        $suffix = "${usedK}k/${totalK}k"
    }

    $lines += Render-Bar -Label "ctx" -Pct $usedPct -Suffix $suffix
}

# 2) Quota / rate-limit bars — deduplicate by short label
$quota = $data.quota
if ($null -ne $quota) {
    $seenLabels = @{}

    $quota.PSObject.Properties | ForEach-Object {
        $key   = $_.Name
        $entry = $_.Value

        $keyLower = $key.ToLower()
        $isGeminiQuota = ($keyLower -match 'gemini|vertex')
        $isClaudeGptQuota = ($keyLower -match 'claude|gpt|anthropic|openai|3p')

        $isGeminiModel = ($modelId -match 'gemini|flash|pro|vertex')
        $isClaudeGptModel = ($modelId -match 'claude|gpt|opus|sonnet|o1|o3|o4|anthropic|openai')

        # Filter: if it's a known quota type, only show if it matches the current model family
        if ($isGeminiQuota -and -not $isGeminiModel) { return }
        if ($isClaudeGptQuota -and -not $isClaudeGptModel) { return }

        # Derive a short label from the bucket key
        $shortLabel = switch -Wildcard ($key) {
            '*5h*'       { '5h'     }
            '*five*'     { '5h'     }
            '*daily*'    { 'day'    }
            '*week*'     { 'weekly' }
            '*month*'    { 'month'  }
            '*annual*'   { 'annual' }
            default      { $key.Substring(0, [Math]::Min(6, $key.Length)) }
        }

        # Skip duplicates — keep only the first bucket per label
        if ($seenLabels.ContainsKey($shortLabel)) { return }
        $seenLabels[$shortLabel] = $true

        # remaining_fraction: 1.0 = fully remaining, 0.0 = exhausted
        $remainFrac = if ($null -ne $entry.remaining_fraction) { [double]$entry.remaining_fraction } else { 1.0 }
        $usedPct = (1.0 - $remainFrac) * 100

        # Countdown suffix
        $suffix = ""
        if ($null -ne $entry.reset_in_seconds -and [double]$entry.reset_in_seconds -gt 0) {
            $suffix = Format-Countdown ([double]$entry.reset_in_seconds)
        }

        $lines += Render-Bar -Label $shortLabel -Pct $usedPct -Suffix $suffix
    }
}

# ── Output ────────────────────────────────────────────────────────────────────
if ($lines.Count -gt 0) {
    $output = $lines -join "`n"
    [System.Console]::Write($output)
}
