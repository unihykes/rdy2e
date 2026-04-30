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

<#
  从整体 JSON 文本上按正则取第一个捕获组（用于非法 JSON 时的降级解析）。
  无匹配时返回 $null。
#>
function Get-HookFallbackRegexCapture {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [Parameter(Mandatory = $false)]
    [int]$CaptureGroup = 1
  )
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }
  $m = [System.Text.RegularExpressions.Regex]::Match($Text, $Pattern)
  if (-not $m.Success -or $CaptureGroup -lt 0 -or $CaptureGroup -ge $m.Groups.Count) {
    return $null
  }
  return [string]$m.Groups[$CaptureGroup].Value
}

<#
  非法 JSON 降级：解析 "jsonField"\s*:\s*"捕获" 写入对象成员；-JsonFieldName 缺省时与 MemberName 相同。
  无匹配不写回。
#>
function Set-HookFallbackJsonQuotedField {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    $Target,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$MemberName,

    [Parameter(Mandatory = $true, Position = 2)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonFieldName,

    [Parameter(Mandatory = $false)]
    [scriptblock]$Convert = $null
  )
  $key = if ($PSBoundParameters.ContainsKey('JsonFieldName')) { $JsonFieldName } else { $MemberName }
  $pattern = '"' + [regex]::Escape($key) + '"\s*:\s*"([^"]*)"'
  $cap = Get-HookFallbackRegexCapture -Text $Text -Pattern $pattern
  if ($null -eq $cap) { return }

  if ($null -eq $Convert) {
    $Target.$MemberName = $cap
  } else {
    $Target.$MemberName = & $Convert $cap
  }
}

<#
  非法 JSON 降级：解析 "jsonField"\s*:\s*(true|false)。
#>
function Set-HookFallbackJsonBoolField {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    $Target,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$MemberName,

    [Parameter(Mandatory = $true, Position = 2)]
    [AllowEmptyString()]
    [string]$Text,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$JsonFieldName
  )
  $key = if ($PSBoundParameters.ContainsKey('JsonFieldName')) { $JsonFieldName } else { $MemberName }
  $pattern = '"' + [regex]::Escape($key) + '"\s*:\s*(true|false)'
  $cap = Get-HookFallbackRegexCapture -Text $Text -Pattern $pattern
  if ($null -eq $cap) { return }

  $Target.$MemberName = [bool]::Parse($cap)
}

function Set-HookFallbackWorkspaceNameFromRoots {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    $Head,

    [Parameter(Mandatory = $true, Position = 1)]
    [AllowEmptyString()]
    [string]$Text
  )
  $v = Get-HookFallbackRegexCapture -Text $Text -Pattern '"workspace_roots"\s*:\s*\[\s*"([^"]*)"'
  if ($null -eq $v) { return }
  if ([string]::IsNullOrWhiteSpace($v)) { return }

  $normalizedRoot = ($v -replace "\\", "/").TrimEnd("/")
  $leaf = Split-Path -Path $normalizedRoot -Leaf
  if (-not [string]::IsNullOrWhiteSpace($leaf)) {
    $Head.WorkspaceName = $leaf
  }
}

<#
  ConvertFrom-Json 得到的嵌套 JSON 对象（例如 tool_input、tool_output）为 PSCustomObject；
  浅拷贝为 Hashtable 便于日志序列化；顶层字符串类型的 content 键改写为 "..."。
#>
function ConvertTo-R2eHookMaskedObjectHashtable {
  param([AllowNull()] [object]$InputObject)

  $ht = @{}
  if ($null -eq $InputObject) {
    return $ht
  }
  if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) {
    return $ht
  }
  foreach ($p in $InputObject.PSObject.Properties) {
    $val = $p.Value
    if ($p.Name -eq 'content' -and $null -ne $val -and $val -is [string]) {
      $ht[$p.Name] = '...'
    } else {
      $ht[$p.Name] = $val
    }
  }
  return $ht
}

<#
  ConvertFrom-Json 得到的 tool_input（PSCustomObject）浅拷贝为 Hashtable，便于日志序列化；
  顶层键名为 context 的项统一改写为 "..."（与其它 hook 中对敏感字符串的处理一致）。
  非 PSCustomObject 时返回空 Hashtable（字符串形式的 tool_input 由 ConvertFrom-R2eHookMcpToolInputForLog 先解析再传入）。
#>
function ConvertTo-R2eHookMaskedToolInputHashtable {
  param([AllowNull()] [object]$InputObject)

  $ht = @{}
  if ($null -eq $InputObject) {
    return $ht
  }
  if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) {
    return $ht
  }
  foreach ($p in $InputObject.PSObject.Properties) {
    if ($p.Name -eq 'context') {
      $ht[$p.Name] = '...'
    } else {
      $ht[$p.Name] = $p.Value
    }
  }
  return $ht
}

<#
  before/after MCP hook：将 tool_input（对象或 JSON 字符串）转为带 context 脱敏的 Hashtable，供日志序列化。
#>
function ConvertFrom-R2eHookMcpToolInputForLog {
  param([AllowNull()] [object]$ToolInput)

  if ($null -eq $ToolInput) {
    return @{}
  }
  if ($ToolInput -is [System.Management.Automation.PSCustomObject]) {
    return ConvertTo-R2eHookMaskedToolInputHashtable -InputObject $ToolInput
  }
  if ($ToolInput -is [string]) {
    $s = [string]$ToolInput
    if ([string]::IsNullOrWhiteSpace($s)) {
      return @{}
    }
    try {
      $nested = $s | ConvertFrom-Json
      if ($nested -is [System.Management.Automation.PSCustomObject]) {
        return ConvertTo-R2eHookMaskedToolInputHashtable -InputObject $nested
      }
    } catch {
      return @{ _unparsed = '...' }
    }
    return @{ _unparsed = '...' }
  }
  return @{ _value = '...' }
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
    Set-HookFallbackJsonQuotedField $head ConversationId $rawInput -JsonFieldName conversation_id
    Set-HookFallbackJsonQuotedField $head GenerationId $rawInput -JsonFieldName generation_id
    Set-HookFallbackJsonQuotedField $head ModelName $rawInput -JsonFieldName model
    Set-HookFallbackJsonQuotedField $head HookEventName $rawInput -JsonFieldName hook_event_name
    Set-HookFallbackWorkspaceNameFromRoots $head $rawInput
  }

  $bodyStr = [string]$bodyStr
  $bodyStr = [System.Text.RegularExpressions.Regex]::Replace($bodyStr, "(\r?\n){3,}", "`n`n")
  $bodyStr = [System.Text.RegularExpressions.Regex]::Replace($bodyStr, "(?:\\r\\n|\\n){3,}", "\n\n")
  return $head, $bodyStr
}

function Get-HookProjectLogPath {
  $projectDir = $env:CURSOR_PROJECT_DIR
  if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
  }
  $dir = Join-Path $projectDir ".cursor/log"
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $filePath = Join-Path $dir "r2e-hook-events.log"
  return $filePath
}
<#
  供日志前缀等：典型为 UUID 样式；空白则原样返回，非空白则取第一个 "-" 前的短段。
#>
function Get-PrettyUuid {
  param(
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$Id
  )
  $s = [string]$Id
  if (-not [string]::IsNullOrWhiteSpace($s)) {
    return ($s -split "-", 2)[0]
  }
  return $s
}
