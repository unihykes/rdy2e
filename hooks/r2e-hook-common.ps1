# 对应 Cursor hook 官方文档中的基础字段（conversation_id、model 等）解析结果；事件正文为 JSON 字符串（各 hook 特有字段等）。
class R2eHookInputHead {
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

function Get-HookInputHeadAndBody {
  <#
    从 stdin 读取 hook 原始 JSON（去掉可能存在的 UTF-8 BOM），并解析出两个值：
    Head（R2eHookInputHead，官方基础字段）与 Body（脱敏/裁剪后的 JSON 或原文，事件特有部分）。
  #>
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

function Get-HookEventsFilePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
  )
  $dir = Join-Path $ProjectDir ".cursor/log"
  return (Join-Path $dir "r2e-hook-events.log")
}

function Format-HookInputHeadLinePrefix {
  <#
    根据 Head（R2eHookInputHead）生成写入 r2e-hook-events.log 时的行首固定段：
    [时间戳][工作区][conversationId 短][generationId 短][model][hook_event_name]
  #>
  param(
    [Parameter(Mandatory = $true)]
    [R2eHookInputHead]$Head
  )

  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $conversationIdShort = [string]$Head.ConversationId
  if (-not [string]::IsNullOrWhiteSpace($conversationIdShort)) {
    $conversationIdShort = ($conversationIdShort -split "-", 2)[0]
  }
  $generationIdShort = [string]$Head.GenerationId
  if (-not [string]::IsNullOrWhiteSpace($generationIdShort)) {
    $generationIdShort = ($generationIdShort -split "-", 2)[0]
  }
  return "[$timestamp][$($Head.WorkspaceName)][$conversationIdShort][$generationIdShort][$($Head.ModelName)][$($Head.HookEventName)]"
}

function Edit-HookInputBody {
  <#
    各 hook 可在 dot-source 本文件之后重新定义同名函数，对 Body（JSON 字符串）做二次处理。
    默认原样返回；由 Invoke-HookInputBodyEdit 在有效 JSON 条件下统一调用。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )
  return $Body
}

function Invoke-HookInputBodyEdit {
  <#
    统一处理各 hook 对 Body 的二次编辑：
    - 仅当 Head.IsValidJson 为 true 时调用 Edit-HookInputBody
    - 无效 JSON 时原样返回，避免各 on-*.ps1 重复 if 判定
  #>
  param(
    [Parameter(Mandatory = $true)]
    [R2eHookInputHead]$Head,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )

  if ($Head.IsValidJson) {
    return (Edit-HookInputBody -Body $Body)
  }
  return $Body
}

function Add-HookEventsFileLine {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [Parameter(Mandatory = $true)]
    [string]$LinePrefix,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body,
    [Parameter(Mandatory = $true)]
    [bool]$IsValidJson
  )

  $filePath = Get-HookEventsFilePath -ProjectDir $ProjectDir
  $parentDir = Split-Path -Path $filePath -Parent
  New-Item -ItemType Directory -Path $parentDir -Force | Out-Null

  if ($IsValidJson) {
    Add-Content -Path $filePath -Value "$LinePrefix $Body" -Encoding utf8
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
