param()

# Force UTF-8 for hook stdout.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Read hook payload from stdin as raw bytes, then decode as UTF-8.
$stdin = [Console]::OpenStandardInput()
$reader = New-Object System.IO.StreamReader($stdin, [System.Text.UTF8Encoding]::new($false), $true)
$rawInput = $reader.ReadToEnd()
$rawInput = $rawInput.TrimStart([char]0xFEFF)
$reader.Dispose()

# Build a stable log payload and avoid logging large/gibberish text fields directly.
$logPayload = $rawInput
$conversationId = "-"
$generationId = "-"
$modelName = "-"
$hookEventName = "-"
$workspaceName = "-"
$isValidJson = $true
try {
  $obj = $rawInput | ConvertFrom-Json
  if ($obj.PSObject.Properties["conversation_id"] -and $obj.conversation_id -is [string]) {
    $conversationId = $obj.conversation_id
    $obj.PSObject.Properties.Remove("conversation_id")
  }
  if ($obj.PSObject.Properties["generation_id"] -and $obj.generation_id -is [string]) {
    $generationId = $obj.generation_id
    $obj.PSObject.Properties.Remove("generation_id")
  }
  if ($obj.PSObject.Properties["model"] -and $obj.model -is [string]) {
    $modelName = $obj.model
    $obj.PSObject.Properties.Remove("model")
  }
  if ($obj.PSObject.Properties["hook_event_name"] -and $obj.hook_event_name -is [string]) {
    $hookEventName = $obj.hook_event_name
    $obj.PSObject.Properties.Remove("hook_event_name")
  }
  if ($obj.PSObject.Properties["workspace_roots"]) {
    $firstRoot = $null
    if ($obj.workspace_roots -is [System.Array]) {
      if ($obj.workspace_roots.Count -gt 0) {
        $firstRoot = [string]$obj.workspace_roots[0]
      }
    } elseif ($obj.workspace_roots -is [string]) {
      $firstRoot = $obj.workspace_roots
    }
    if (-not [string]::IsNullOrWhiteSpace($firstRoot)) {
      $normalizedRoot = ($firstRoot -replace "\\", "/").TrimEnd("/")
      $leaf = Split-Path -Path $normalizedRoot -Leaf
      if (-not [string]::IsNullOrWhiteSpace($leaf)) {
        $workspaceName = $leaf
      }
    }
    $obj.PSObject.Properties.Remove("workspace_roots")
  }
  if ($obj.PSObject.Properties["cursor_version"]) {
    $obj.PSObject.Properties.Remove("cursor_version")
  }
  if ($obj.PSObject.Properties["user_email"]) {
    $obj.PSObject.Properties.Remove("user_email")
  }
  if ($null -ne $obj.prompt -and $obj.prompt -is [string]) {
    $obj.prompt = "..."
  }
  if ($null -ne $obj.text -and $obj.text -is [string]) {
    $obj.text = "..."
  }
  if ($null -ne $obj.content -and $obj.content -is [string]) {
    $obj.content = "..."
  }
  $logPayload = $obj | ConvertTo-Json -Compress -Depth 20
} catch {
  $isValidJson = $false
  $logPayload = $rawInput
  $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"conversation_id"\s*:\s*"([^"]*)"')
  if ($m.Success) { $conversationId = $m.Groups[1].Value }
  $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"generation_id"\s*:\s*"([^"]*)"')
  if ($m.Success) { $generationId = $m.Groups[1].Value }
  $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"model"\s*:\s*"([^"]*)"')
  if ($m.Success) { $modelName = $m.Groups[1].Value }
  $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"hook_event_name"\s*:\s*"([^"]*)"')
  if ($m.Success) { $hookEventName = $m.Groups[1].Value }
  $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"workspace_roots"\s*:\s*\[\s*"([^"]*)"')
  if ($m.Success) {
    $firstRoot = $m.Groups[1].Value
    if (-not [string]::IsNullOrWhiteSpace($firstRoot)) {
      $normalizedRoot = ($firstRoot -replace "\\", "/").TrimEnd("/")
      $leaf = Split-Path -Path $normalizedRoot -Leaf
      if (-not [string]::IsNullOrWhiteSpace($leaf)) {
        $workspaceName = $leaf
      }
    }
  }
}

# Reduce excessive line breaks for better log readability.
$logPayload = [string]$logPayload
# Collapse real consecutive newlines to at most two.
$logPayload = [System.Text.RegularExpressions.Regex]::Replace($logPayload, "(\r?\n){3,}", "`n`n")
# Collapse escaped consecutive newlines (\n / \r\n) to at most two.
$logPayload = [System.Text.RegularExpressions.Regex]::Replace($logPayload, "(?:\\r\\n|\\n){3,}", "\n\n")

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
if ($isValidJson) {
  $prefix = "[$timestamp][$workspaceName][$conversationId][$generationId][$modelName][$hookEventName]"
  Add-Content -Path $logPath -Value "$prefix $logPayload" -Encoding utf8
} else {
  Add-Content -Path $logPath -Value "[$timestamp][$workspaceName][$conversationId][$generationId][$modelName][$hookEventName] invalid json" -Encoding utf8
}

# Normalize empty input for easier debugging in UI.
if ([string]::IsNullOrWhiteSpace($rawInput)) {
  $rawInput = "(empty)"
}

# Return valid hook JSON response.
@{
  permission = "allow"
  user_message = "ok"
} | ConvertTo-Json -Compress
exit 0
