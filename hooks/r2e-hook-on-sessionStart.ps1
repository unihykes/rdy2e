<# 
Hook: sessionStart
在创建新的 composer 会话时调用。此 hook 以即发即忘方式运行；agent 循环不会等待其完成，也不会强制要求阻塞式响应。使用此 hook 来设置会话专属环境变量或注入额外上下文。
#>

param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

<#
输入字段	类型	描述
session_id	string	此会话的唯一标识符 (与 conversation_id 相同)
is_background_agent	boolean	该会话是后台 agent 会话还是交互式会话
composer_mode	string (optional)	composer 启动时的模式 (例如 "agent"、"ask"、"edit")
#>
class R2eHookSessionStartInputBody {
  [string]$session_id
  [bool]$is_background_agent
  [string]$composer_mode
  [hashtable]$others

  [string] ToJsonString() {
    $h = @{
      session_id          = $this.session_id
      is_background_agent = $this.is_background_agent
      composer_mode       = $this.composer_mode
    }
    if ($null -ne $this.others -and $this.others.Count -gt 0) {
      $h.others = $this.others
    }
    return ($h | ConvertTo-Json -Compress -Depth 20)
  }
}

function Get-HookInputBody {
  $head, $bodyStr = Get-HookInputHeadAndBody

  if ([string]::IsNullOrWhiteSpace($bodyStr)) {
    return $head, ([R2eHookSessionStartInputBody]::new())
  }

  # 外层整条 stdin 非合法 JSON：与 common 中 catch 类似，用正则抽出 sessionStart 已知字段；日志一律 ToJsonString
  if (-not $head.IsValidJson) {
    $inst = [R2eHookSessionStartInputBody]::new()
    $m = [System.Text.RegularExpressions.Regex]::Match($bodyStr, '"session_id"\s*:\s*"([^"]*)"')
    if ($m.Success) {
      $inst.session_id = Get-PrettyUuid -Id $m.Groups[1].Value
    }
    $m = [System.Text.RegularExpressions.Regex]::Match($bodyStr, '"is_background_agent"\s*:\s*(true|false)')
    if ($m.Success) {
      $inst.is_background_agent = [bool]::Parse($m.Groups[1].Value)
    }
    $m = [System.Text.RegularExpressions.Regex]::Match($bodyStr, '"composer_mode"\s*:\s*"([^"]*)"')
    if ($m.Success) {
      $inst.composer_mode = $m.Groups[1].Value
    }
    $inst.others = @{
      _invalidOuterJson = $true
      _rawBodyStr       = $bodyStr
    }
    return $head, $inst
  }

  try {
    $obj = $bodyStr | ConvertFrom-Json
    $inst = [R2eHookSessionStartInputBody]::new()
    if ($obj.PSObject.Properties["session_id"]) {
      $inst.session_id = Get-PrettyUuid -Id ([string]$obj.session_id)
      $obj.PSObject.Properties.Remove("session_id")
    }
    if ($obj.PSObject.Properties["is_background_agent"]) {
      $inst.is_background_agent = [bool]$obj.is_background_agent
      $obj.PSObject.Properties.Remove("is_background_agent")
    }
    if ($obj.PSObject.Properties["composer_mode"]) {
      $inst.composer_mode = [string]$obj.composer_mode
      $obj.PSObject.Properties.Remove("composer_mode")
    }
    foreach ($prop in $obj.PSObject.Properties) {
      if ($null -eq $inst.others) {
        $inst.others = @{}
      }
      $inst.others[$prop.Name] = $prop.Value
    }
    return $head, $inst
  }
  catch {
    $inst = [R2eHookSessionStartInputBody]::new()
    $inst.others = @{ _errorMessage = "invalid json" }
    return $head, $inst
  }
}

<#
输出字段	类型	描述
env	object (optional)	为此会话设置的环境变量。对后续所有 hook 的执行均可用
additional_context	string (optional)	要添加到对话初始系统上下文中的额外上下文
#>
function Build-HookResponse {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [R2eHookSessionStartInputBody]$Body
  )
  $out = @{}
  return ($out | ConvertTo-Json -Compress -Depth 20)
}

# 脚本入口
Set-HookOutputUtf8
$head, $body = Get-HookInputBody
Add-Content -Encoding utf8 -Path (Get-HookProjectLogPath) -Value (
  "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')]" +
    "[$($head.WorkspaceName)]" +
    "[$(Get-PrettyUuid -Id $head.ConversationId)]" +
    "[$(Get-PrettyUuid -Id $head.GenerationId)]" +
    "[$($head.ModelName)]" +
    "[$($head.HookEventName)]" +
    " " +
    $( $body.ToJsonString() )
)

$response = Build-HookResponse -Body $body
Write-Output $response
exit 0


