# 从 stdin JSON 解析出的会话与事件元信息（供上层 hook 任意使用，不限于写文件）
class R2eHookStdinContext {
  [string]$ConversationId = "-"
  [string]$GenerationId = "-"
  [string]$ModelName = "-"
  [string]$HookEventName = "-"
  [string]$WorkspaceName = "-"
  [bool]$IsValidJson = $true
}

function Set-HookOutputUtf8 {
  # 统一 stdout 编码，避免中文输出乱码
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}

function Read-HookRawInput {
  # 从 stdin 读取 hook 的原始 JSON 入参，并去掉可能存在的 UTF-8 BOM
  $stdin = [Console]::OpenStandardInput()
  $reader = New-Object System.IO.StreamReader($stdin, [System.Text.UTF8Encoding]::new($false), $true)
  $rawInput = $reader.ReadToEnd()
  $rawInput = $rawInput.TrimStart([char]0xFEFF)
  $reader.Dispose()
  return $rawInput
}

function Get-HookStdinPayload {
  <#
    从 hook stdin 原始字符串解析出两个值：Context（R2eHookStdinContext）与 Payload（脱敏/裁剪后的 JSON 或原文）。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawInput
  )

  $ctx = [R2eHookStdinContext]::new()
  $payloadStr = $RawInput

  try {
    $obj = $RawInput | ConvertFrom-Json
    if ($obj.PSObject.Properties["conversation_id"] -and $obj.conversation_id -is [string]) {
      $ctx.ConversationId = $obj.conversation_id
      $obj.PSObject.Properties.Remove("conversation_id")
    }
    if ($obj.PSObject.Properties["generation_id"] -and $obj.generation_id -is [string]) {
      $ctx.GenerationId = $obj.generation_id
      $obj.PSObject.Properties.Remove("generation_id")
    }
    if ($obj.PSObject.Properties["model"] -and $obj.model -is [string]) {
      $ctx.ModelName = $obj.model
      $obj.PSObject.Properties.Remove("model")
    }
    if ($obj.PSObject.Properties["hook_event_name"] -and $obj.hook_event_name -is [string]) {
      $ctx.HookEventName = $obj.hook_event_name
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
          $ctx.WorkspaceName = $leaf
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
    $payloadStr = $obj | ConvertTo-Json -Compress -Depth 20
  } catch {
    $ctx.IsValidJson = $false
    $payloadStr = $RawInput
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"conversation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $ctx.ConversationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"generation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $ctx.GenerationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"model"\s*:\s*"([^"]*)"')
    if ($m.Success) { $ctx.ModelName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"hook_event_name"\s*:\s*"([^"]*)"')
    if ($m.Success) { $ctx.HookEventName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"workspace_roots"\s*:\s*\[\s*"([^"]*)"')
    if ($m.Success) {
      $firstRoot = $m.Groups[1].Value
      if (-not [string]::IsNullOrWhiteSpace($firstRoot)) {
        $normalizedRoot = ($firstRoot -replace "\\", "/").TrimEnd("/")
        $leaf = Split-Path -Path $normalizedRoot -Leaf
        if (-not [string]::IsNullOrWhiteSpace($leaf)) {
          $ctx.WorkspaceName = $leaf
        }
      }
    }
  }

  $payloadStr = [string]$payloadStr
  $payloadStr = [System.Text.RegularExpressions.Regex]::Replace($payloadStr, "(\r?\n){3,}", "`n`n")
  $payloadStr = [System.Text.RegularExpressions.Regex]::Replace($payloadStr, "(?:\\r\\n|\\n){3,}", "\n\n")
  return $ctx, $payloadStr
}

function Get-HookProjectDir {
  $projectDir = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  }
  return $projectDir
}

function Get-HookEventsFilePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
  )
  $dir = Join-Path $ProjectDir ".cursor/log"
  return (Join-Path $dir "r2e-hook-events.log")
}

function Format-HookStdinContextLinePrefix {
  <#
    根据 Get-HookStdinPayload 得到的 Context，生成写入 r2e-hook-events.log 时的行首固定段：
    [时间戳][工作区][conversationId 短][generationId 短][model][hook_event_name]
  #>
  param(
    [Parameter(Mandatory = $true)]
    [R2eHookStdinContext]$Context
  )

  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $conversationIdShort = [string]$Context.ConversationId
  if (-not [string]::IsNullOrWhiteSpace($conversationIdShort)) {
    $conversationIdShort = ($conversationIdShort -split "-", 2)[0]
  }
  $generationIdShort = [string]$Context.GenerationId
  if (-not [string]::IsNullOrWhiteSpace($generationIdShort)) {
    $generationIdShort = ($generationIdShort -split "-", 2)[0]
  }
  return "[$timestamp][$($Context.WorkspaceName)][$conversationIdShort][$generationIdShort][$($Context.ModelName)][$($Context.HookEventName)]"
}

function Edit-HookStdinPayload {
  <#
    各 hook 可在 dot-source 本文件之后重新定义同名函数，对 Payload（JSON 字符串）做二次处理。
    默认原样返回；仅当 Context.IsValidJson 为 true 时由各 on-*.ps1 调用。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Payload
  )
  return $Payload
}

function Add-HookEventsFileLine {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [Parameter(Mandatory = $true)]
    [string]$LinePrefix,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Payload,
    [Parameter(Mandatory = $true)]
    [bool]$IsValidJson
  )

  $filePath = Get-HookEventsFilePath -ProjectDir $ProjectDir
  $parentDir = Split-Path -Path $filePath -Parent
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

  if ($IsValidJson) {
    Add-Content -Path $filePath -Value "$LinePrefix $Payload" -Encoding utf8
  }
  else {
    Add-Content -Path $filePath -Value "$LinePrefix invalid json" -Encoding utf8
  }
}

function Write-HookAllowResponse {
  @{
    permission = "allow"
    user_message = "ok"
  } | ConvertTo-Json -Compress
}
