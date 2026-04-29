# 日志行 head 中除时间戳外的各字段（由 stdin JSON 解析或正则回退得到）
class R2eHookLogHeadInfo {
  [string]$ConversationId = "-"
  [string]$GenerationId = "-"
  [string]$ModelName = "-"
  [string]$HookEventName = "-"
  [string]$WorkspaceName = "-"
  [bool]$IsValidJson = $true
}

# 一条 hook 日志的 head 元数据与 body（JSON 字符串）；body 在函数内填充
class R2eHookLogEntryParts {
  [string]$Body = ""
  [R2eHookLogHeadInfo]$HeadFields = [R2eHookLogHeadInfo]::new()
}

function Set-HookOutputUtf8 {
  # 统一 stdout 编码，避免中文日志乱码
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

function Get-HookStdinLogEntryParts {
  <#
    从 hook stdin 原始字符串解析出日志 head 各字段与 body（脱敏/裁剪后的 JSON 或原文）。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawInput
  )

  $entry = [R2eHookLogEntryParts]::new()
  $h = $entry.HeadFields
  $body = $RawInput

  try {
    # 优先按 JSON 解析：提取关键信息并清洗敏感/冗余字段
    $obj = $RawInput | ConvertFrom-Json
    if ($obj.PSObject.Properties["conversation_id"] -and $obj.conversation_id -is [string]) {
      $h.ConversationId = $obj.conversation_id
      # 移除：已进入日志前缀，无需在 JSON payload 中重复
      $obj.PSObject.Properties.Remove("conversation_id")
    }
    if ($obj.PSObject.Properties["generation_id"] -and $obj.generation_id -is [string]) {
      $h.GenerationId = $obj.generation_id
      # 移除：已进入日志前缀，无需在 JSON payload 中重复
      $obj.PSObject.Properties.Remove("generation_id")
    }
    if ($obj.PSObject.Properties["model"] -and $obj.model -is [string]) {
      $h.ModelName = $obj.model
      # 移除：已进入日志前缀，无需在 JSON payload 中重复
      $obj.PSObject.Properties.Remove("model")
    }
    if ($obj.PSObject.Properties["hook_event_name"] -and $obj.hook_event_name -is [string]) {
      $h.HookEventName = $obj.hook_event_name
      # 移除：已进入日志前缀，无需在 JSON payload 中重复
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
          $h.WorkspaceName = $leaf
        }
      }
      # 移除：仅用于提取工作区名，完整路径不写入日志以减少噪声
      $obj.PSObject.Properties.Remove("workspace_roots")
    }
    if ($obj.PSObject.Properties["cursor_version"]) {
      # 移除：版本信息对本地 hook 排查价值较低，避免日志冗余
      $obj.PSObject.Properties.Remove("cursor_version")
    }
    if ($obj.PSObject.Properties["user_email"]) {
      # 移除：用户隐私字段，不写入日志
      $obj.PSObject.Properties.Remove("user_email")
    }
    if ($obj.PSObject.Properties["transcript_path"]) {
      # 移除：本地绝对路径字段，可能包含敏感目录信息
      $obj.PSObject.Properties.Remove("transcript_path")
    }
    if ($null -ne $obj.prompt -and $obj.prompt -is [string]) {
      # 脱敏：提示词正文可能包含敏感内容，仅保留占位符
      $obj.prompt = "..."
    }
    if ($null -ne $obj.text -and $obj.text -is [string]) {
      # 脱敏：文本正文可能包含敏感内容，仅保留占位符
      $obj.text = "..."
    }
    if ($null -ne $obj.content -and $obj.content -is [string]) {
      # 脱敏：内容正文可能包含敏感内容，仅保留占位符
      $obj.content = "..."
    }
    # 重新序列化，确保结构合法（不会出现手工拼接导致的尾逗号）
    $body = $obj | ConvertTo-Json -Compress -Depth 20
  } catch {
    # 非 JSON 输入时降级处理：保留原文，并尽量用正则提取关键字段
    $h.IsValidJson = $false
    $body = $RawInput
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"conversation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $h.ConversationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"generation_id"\s*:\s*"([^"]*)"')
    if ($m.Success) { $h.GenerationId = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"model"\s*:\s*"([^"]*)"')
    if ($m.Success) { $h.ModelName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"hook_event_name"\s*:\s*"([^"]*)"')
    if ($m.Success) { $h.HookEventName = $m.Groups[1].Value }
    $m = [System.Text.RegularExpressions.Regex]::Match($RawInput, '"workspace_roots"\s*:\s*\[\s*"([^"]*)"')
    if ($m.Success) {
      $firstRoot = $m.Groups[1].Value
      if (-not [string]::IsNullOrWhiteSpace($firstRoot)) {
        $normalizedRoot = ($firstRoot -replace "\\", "/").TrimEnd("/")
        $leaf = Split-Path -Path $normalizedRoot -Leaf
        if (-not [string]::IsNullOrWhiteSpace($leaf)) {
          $h.WorkspaceName = $leaf
        }
      }
    }
  }

  $body = [string]$body
  # 压缩过多空行，避免日志被无意义换行撑大
  $body = [System.Text.RegularExpressions.Regex]::Replace($body, "(\r?\n){3,}", "`n`n")
  $body = [System.Text.RegularExpressions.Regex]::Replace($body, "(?:\\r\\n|\\n){3,}", "\n\n")
  $entry.Body = $body
  return $entry
}

function Get-HookProjectDir {
  # 优先使用 Cursor 注入的项目目录；缺失时退回脚本上级目录
  $projectDir = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  }
  return $projectDir
}

function Get-HookEventsLogPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
  )
  $logDir = Join-Path $ProjectDir ".cursor/log"
  return (Join-Path $logDir "r2e-hook-events.log")
}

function Get-HookLogHead {
  <#
    由 Get-HookStdinLogEntryParts 得到的 Entry 生成日志行 head（与各事件统一的 [时间戳][…]… 格式）：
    [时间戳][工作区][conversationId 短][generationId 短][model][hook_event_name]
    与 body（JSON 字符串）拼成完整一行。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [R2eHookLogEntryParts]$Entry
  )

  $hf = $Entry.HeadFields
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
  $conversationIdShort = [string]$hf.ConversationId
  if (-not [string]::IsNullOrWhiteSpace($conversationIdShort)) {
    $conversationIdShort = ($conversationIdShort -split "-", 2)[0]
  }
  $generationIdShort = [string]$hf.GenerationId
  if (-not [string]::IsNullOrWhiteSpace($generationIdShort)) {
    $generationIdShort = ($generationIdShort -split "-", 2)[0]
  }
  return "[$timestamp][$($hf.WorkspaceName)][$conversationIdShort][$generationIdShort][$($hf.ModelName)][$($hf.HookEventName)]"
}

function Edit-HookLogBody {
  <#
    各 hook 脚本可在 dot-source 本文件之后重新定义同名函数，对 body（JSON 字符串）做二次剪裁。
    默认原样返回；仅当 Entry.HeadFields.IsValidJson 为 true 时才会调用。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )
  return $Body
}

function Add-HookLogLine {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [Parameter(Mandatory = $true)]
    [string]$Head,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body,
    [Parameter(Mandatory = $true)]
    [bool]$IsValidJson
  )

  $logPath = Get-HookEventsLogPath -ProjectDir $ProjectDir
  $logDir = Split-Path -Path $logPath -Parent
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null

  if ($IsValidJson) {
    Add-Content -Path $logPath -Value "$Head $Body" -Encoding utf8
  }
  else {
    Add-Content -Path $logPath -Value "$Head invalid json" -Encoding utf8
  }
}

function Write-HookAllowResponse {
  # 默认放行，避免 hook 影响主流程执行
  @{
    permission = "allow"
    user_message = "ok"
  } | ConvertTo-Json -Compress
}
