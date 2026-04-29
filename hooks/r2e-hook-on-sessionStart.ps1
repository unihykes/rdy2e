<# 
Hook: sessionStart
在创建新的 composer 会话时调用。此 hook 以即发即忘方式运行；agent 循环不会等待其完成，也不会强制要求阻塞式响应。
使用此 hook 来设置会话专属环境变量或注入额外上下文。

输入字段	类型	描述
session_id	string	此会话的唯一标识符 (与 conversation_id 相同)
is_background_agent	boolean	该会话是后台 agent 会话还是交互式会话
composer_mode	string (optional)	composer 启动时的模式 (例如 "agent"、"ask"、"edit")

输出字段	类型	描述
env	object (optional)	为此会话设置的环境变量。对后续所有 hook 的执行均可用
additional_context	string (optional)	要添加到对话初始系统上下文中的额外上下文
#>

param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

function Edit-HookStdinPayload {
  # 对 stdin 解析后的 JSON 字符串做二次处理
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Payload
  )
  try {
    $obj = $Payload | ConvertFrom-Json
    if ($obj.PSObject.Properties["session_id"] -and $obj.session_id -is [string]) {
      $sid = [string]$obj.session_id
      if (-not [string]::IsNullOrWhiteSpace($sid)) {
        $obj.session_id = ($sid -split "-", 2)[0]
      }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 20)
  } catch {
    return $Payload
  }
}

function Write-HookAllowResponse {
  # 默认发送空对象 {}，表示不改变环境与上下文。
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [hashtable]$Env,
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$AdditionalContext
  )
  $out = @{}
  if ($null -ne $Env -and $Env.Count -gt 0) {
    $out.env = $Env
  }
  if ($null -ne $AdditionalContext) {
    $trimmed = $AdditionalContext.Trim()
    if ($trimmed.Length -gt 0) {
      $out.additional_context = $AdditionalContext
    }
  }
  $out | ConvertTo-Json -Compress -Depth 20
}

Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$context, $payload = Get-HookStdinPayload -RawInput $rawInput
$projectDir = Get-HookProjectDir
$linePrefix = Format-HookStdinContextLinePrefix -Context $context
if ($context.IsValidJson) {
  $payload = Edit-HookStdinPayload -Payload $payload
}
Add-HookEventsFileLine -ProjectDir $projectDir -LinePrefix $linePrefix -Payload $payload -IsValidJson $context.IsValidJson

#usage: Write-HookAllowResponse -Env @{a=1} -AdditionalContext "session_start"
Write-HookAllowResponse
exit 0
