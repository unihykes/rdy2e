param()

# Force UTF-8 for hook stdout.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Read hook payload from stdin as raw bytes, then decode as UTF-8.
$stdin = [Console]::OpenStandardInput()
$reader = New-Object System.IO.StreamReader($stdin, [System.Text.UTF8Encoding]::new($false), $true)
$rawInput = $reader.ReadToEnd()
$rawInput = $rawInput.TrimStart([char]0xFEFF)
$reader.Dispose()

# Prefer Cursor-provided project root; fallback to parent of hooks folder.
$projectDir = $env:CURSOR_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir)) {
  $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

# Ensure log directory exists before writing.
$logDir = Join-Path $projectDir ".cursor/log"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# Append one log line per hook invocation.
$logPath = Join-Path $logDir "r2e-hooks.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
Add-Content -Path $logPath -Value "[$timestamp] $rawInput" -Encoding utf8

# Normalize empty input for easier debugging in UI.
if ([string]::IsNullOrWhiteSpace($rawInput)) {
  $rawInput = "(empty)"
}

# Return valid hook JSON response.
@{
  permission = "allow"
  user_message = "ok: $rawInput"
} | ConvertTo-Json -Compress
exit 0
