# scripts/ask-local.ps1
# Calls a local Ollama instance to generate code or content.
# Consult pattern only -- generates text for the agent to review. Never edits files directly.
#
# Setup:
#   1. Install Ollama: https://ollama.com
#   2. Pull your models: ollama pull qwen2.5-coder:7b && ollama pull qwen2.5-coder:32b
#   3. Update $OLLAMA_URL below to point to your Ollama instance
#   4. Run: .\scripts\ask-local.ps1 -Prompt "write a vitest test for handler.js" -Mode quality
#
# Usage:
#   .\scripts\ask-local.ps1 -Prompt "write a vitest mock for db.js" -Mode quality
#   .\scripts\ask-local.ps1 -Prompt "summarise this function" -Mode fast

param(
    [Parameter(Mandatory)]
    [string] $Prompt,

    [ValidateSet('fast', 'quality')]
    [string] $Mode = 'quality',

    [int] $TimeoutSeconds = 120
)

# -- Config --------------------------------------------------------------------
# Update these values for your setup:
$OLLAMA_URL    = 'http://localhost:11434/api/generate'   # or http://<remote-ip>:11434/api/generate
$MODEL_FAST    = 'qwen2.5-coder:7b'                     # fast model for short tasks (~5s)
$MODEL_QUALITY = 'qwen2.5-coder:32b'                    # quality model for full files (30-60s)

$LOCK_FILE     = Join-Path $env:TEMP 'ollama-local-ai.lock'
$LOCK_TIMEOUT  = 180   # seconds to wait for lock
$LOCK_MAX_AGE  = 600   # seconds before treating lock as stale (10 min)
$SYSTEM_PROMPT = 'You are an expert software engineer. Output only the requested code or content. No explanations, no markdown fences unless the output IS markdown. No commentary.'

$model = if ($Mode -eq 'fast') { $MODEL_FAST } else { $MODEL_QUALITY }

# -- Lock: prevent parallel calls that degrade Ollama performance --------------
$waited = 0
while (Test-Path $LOCK_FILE) {
    $lockAge = (Get-Date) - (Get-Item $LOCK_FILE).LastWriteTime
    if ($lockAge.TotalSeconds -gt $LOCK_MAX_AGE) {
        Write-Host "Stale lock detected (age: $([int]$lockAge.TotalSeconds)s). Removing."
        Remove-Item $LOCK_FILE -Force
        break
    }
    if ($waited -ge $LOCK_TIMEOUT) {
        Write-Error "Timed out waiting for Local AI lock after ${LOCK_TIMEOUT}s. Another request may be stuck."
        exit 1
    }
    Write-Host "Local AI is busy, waiting... ($waited s)"
    Start-Sleep -Seconds 5
    $waited += 5
}

# Acquire lock
[void][System.IO.File]::WriteAllText($LOCK_FILE, "$PID")

try {
    # -- Build request ----------------------------------------------------------
    $body = [ordered]@{
        model  = $model
        system = $SYSTEM_PROMPT
        prompt = $Prompt
        stream = $false
        options = [ordered]@{
            temperature = 0.1
        }
    } | ConvertTo-Json -Depth 5 -Compress

    Write-Host "Calling local AI ($model)..." -ForegroundColor DarkGray

    # -- Call Ollama ------------------------------------------------------------
    $response = Invoke-RestMethod `
        -Uri         $OLLAMA_URL `
        -Method      POST `
        -ContentType 'application/json' `
        -Body        $body `
        -TimeoutSec  $TimeoutSeconds

    # /api/generate returns { response: "..." }
    $response.response
}
catch [System.Net.WebException] {
    Write-Error "Local AI unreachable at $OLLAMA_URL -- is Ollama running? Check your OLLAMA_URL setting in this script."
    exit 1
}
catch [System.TimeoutException] {
    Write-Error "Local AI request timed out after ${TimeoutSeconds}s."
    exit 1
}
catch {
    Write-Error "Local AI error: $_"
    exit 1
}
finally {
    # Always release lock
    if (Test-Path $LOCK_FILE) {
        $owner = Get-Content $LOCK_FILE -ErrorAction SilentlyContinue
        if ($owner -eq "$PID") {
            Remove-Item $LOCK_FILE -Force
        }
    }
}
