function Set-HookOutputUtf8 {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}

function Read-HookRawInput {
  $stdin = [Console]::OpenStandardInput()
  $reader = New-Object System.IO.StreamReader($stdin, [System.Text.UTF8Encoding]::new($false), $true)
  $rawInput = $reader.ReadToEnd()
  $rawInput = $rawInput.TrimStart([char]0xFEFF)
  $reader.Dispose()
  return $rawInput
}

function Get-HookLogData {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawInput
  )

  $logPayload = $RawInput
  $conversationId = "-"
  $generationId = "-"
  $modelName = "-"
  $hookEventName = "-"
  $workspaceName = "-"
  $isValidJson = $true

  try {
    $obj = $RawInput | ConvertFrom-Json
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
    $logPayload = $RawInput
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"conversation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $conversationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"generation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $generationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"model"\s*:\s*"([^"]*)"')
    if ($m.Success) { $modelName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"hook_event_name"\s*:\s*"([^"]*)"')
    if ($m.Success) { $hookEventName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"workspace_roots"\s*:\s*\[\s*"([^"]*)"')
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

  $logPayload = [string]$logPayload
  $logPayload = [System.Text.RegularExpressions.Regex]::Replace($logPayload, "(\r?\n){3,}", "`n`n")
  $logPayload = [System.Text.RegularExpressions.Regex]::Replace($logPayload, "(?:\\r\\n|\\n){3,}", "\n\n")

  return @{
    LogPayload = $logPayload
    ConversationId = $conversationId
    GenerationId = $generationId
    ModelName = $modelName
    HookEventName = $hookEventName
    WorkspaceName = $workspaceName
    IsValidJson = $isValidJson
  }
}

function Get-HookProjectDir {
  $projectDir = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  }
  return $projectDir
}

function Write-HookLog {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$LogData,
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
  )

  $logDir = Join-Path $ProjectDir ".cursor/log"
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null

  $logPath = Join-Path $logDir "r2e-hooks.log"
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $conversationIdShort = [string]$LogData.ConversationId
  if (-not [string]::IsNullOrWhiteSpace($conversationIdShort)) {
    $conversationIdShort = ($conversationIdShort -split "-", 2)[0]
  }
  $generationIdShort = [string]$LogData.GenerationId
  if (-not [string]::IsNullOrWhiteSpace($generationIdShort)) {
    $generationIdShort = ($generationIdShort -split "-", 2)[0]
  }
  $prefix = "[$timestamp][$($LogData.WorkspaceName)][$conversationIdShort][$generationIdShort][$($LogData.ModelName)][$($LogData.HookEventName)]"

  if ($LogData.IsValidJson) {
    Add-Content -Path $logPath -Value "$prefix $($LogData.LogPayload)" -Encoding utf8
  } else {
    Add-Content -Path $logPath -Value "$prefix invalid json" -Encoding utf8
  }
}

function Normalize-HookRawInputForDebug {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$RawInput
  )

  if ([string]::IsNullOrWhiteSpace($RawInput)) {
    return "(empty)"
  }
  return $RawInput
}

function Write-HookAllowResponse {
  @{
    permission = "allow"
    user_message = "ok"
  } | ConvertTo-Json -Compress
}
