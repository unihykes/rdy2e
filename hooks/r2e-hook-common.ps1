# 对应 Cursor hook 官方文档中的基础字段（conversation_id、model 等
class R2eHookInputHead {
  [string]$ConversationId = "-"
  [string]$GenerationId = "-"
  [string]$ModelName = "-"
  [string]$HookEventName = "-"
  [string]$WorkspaceName = "-"
  [bool]$IsValidJson = $true
}

# 统一 stdout 编码，避免中文输出乱码
function Set-HookOutputUtf8 {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}

function Get-HookInputHeadAndBody {
  $stdin = [Console]::OpenStandardInput()
  $reader = New-Object System.IO.StreamReader($stdin, [System.Text.UTF8Encoding]::new($false), $true)
  $rawInput = $reader.ReadToEnd()
  $rawInput = $rawInput.TrimStart([char]0xFEFF)
  $reader.Dispose()

  $head = [R2eHookInputHead]::new()
  $bodyStr = $rawInput

  try {
    $obj = $rawInput | ConvertFrom-Json
    if ($obj.PSObject.Properties["conversation_id"] -and $obj.conversation_id -is [string]) {
      $head.ConversationId = $obj.conversation_id
      $obj.PSObject.Properties.Remove("conversation_id")
    }
    if ($obj.PSObject.Properties["generation_id"] -and $obj.generation_id -is [string]) {
      $head.GenerationId = $obj.generation_id
      $obj.PSObject.Properties.Remove("generation_id")
    }
    if ($obj.PSObject.Properties["model"] -and $obj.model -is [string]) {
      $head.ModelName = $obj.model
      $obj.PSObject.Properties.Remove("model")
    }
    if ($obj.PSObject.Properties["hook_event_name"] -and $obj.hook_event_name -is [string]) {
      $head.HookEventName = $obj.hook_event_name
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
          $head.WorkspaceName = $leaf
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
    if ($obj.PSObject.Properties["transcript_path"]) {
      $obj.PSObject.Properties.Remove("transcript_path")
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
    $bodyStr = $obj | ConvertTo-Json -Compress -Depth 20
  } catch {
    $head.IsValidJson = $false
    $bodyStr = $rawInput
    $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"conversation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $head.ConversationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"generation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $head.GenerationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"model"\s*:\s*"([^"]*)"')
    if ($m.Success) { $head.ModelName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"hook_event_name"\s*:\s*"([^"]*)"')
    if ($m.Success) { $head.HookEventName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($rawInput, '"workspace_roots"\s*:\s*\[\s*"([^"]*)"')
    if ($m.Success) {
      $firstRoot = $m.Groups[1].Value
      if (-not [string]::IsNullOrWhiteSpace($firstRoot)) {
        $normalizedRoot = ($firstRoot -replace "\\", "/").TrimEnd("/")
        $leaf = Split-Path -Path $normalizedRoot -Leaf
        if (-not [string]::IsNullOrWhiteSpace($leaf)) {
          $head.WorkspaceName = $leaf
        }
      }
    }
  }

  $bodyStr = [string]$bodyStr
  $bodyStr = [System.Text.RegularExpressions.Regex]::Replace($bodyStr, "(\r?\n){3,}", "`n`n")
  $bodyStr = [System.Text.RegularExpressions.Regex]::Replace($bodyStr, "(?:\\r\\n|\\n){3,}", "\n\n")
  return $head, $bodyStr
}

function Get-HookProjectDir {
  $projectDir = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  }
  return $projectDir
}

function Log-HookEvent {
  param(
    [Parameter(Mandatory = $true)]
    [R2eHookInputHead]$Head,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$BodyLog
  )

  $projectDir = Get-HookProjectDir
  $dir = Join-Path $projectDir ".cursor/log"
  $filePath = Join-Path $dir "r2e-hook-events.log"
  $parentDir = Split-Path -Path $filePath -Parent
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $conversationIdShort = [string]$Head.ConversationId
  if (-not [string]::IsNullOrWhiteSpace($conversationIdShort)) {
    $conversationIdShort = ($conversationIdShort -split "-", 2)[0]
  }
  $generationIdShort = [string]$Head.GenerationId
  if (-not [string]::IsNullOrWhiteSpace($generationIdShort)) {
    $generationIdShort = ($generationIdShort -split "-", 2)[0]
  }
  $linePrefix = "[$timestamp][$($Head.WorkspaceName)][$conversationIdShort][$generationIdShort][$($Head.ModelName)][$($Head.HookEventName)]"

  if ($Head.IsValidJson) {
    Add-Content -Path $filePath -Value "$LinePrefix $BodyLog" -Encoding utf8
  }
  else {
    Add-Content -Path $filePath -Value "$LinePrefix invalid json" -Encoding utf8
  }
}
