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

Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$logData = Get-HookLogData -RawInput $rawInput
$projectDir = Get-HookProjectDir
$head = Get-HookLogHead -LogData $logData
$body = $logData.LogPayload
if ($logData.IsValidJson) {
  $body = Edit-HookLogBody -Body $body
}
Add-HookLogLine -ProjectDir $projectDir -Head $head -Body $body -IsValidJson $logData.IsValidJson
Write-HookAllowResponse
exit 0
