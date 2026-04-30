<#
Hook: subagentStart
在创建子 agent 会话时触发。
#>

param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

<#
输入字段                类型        描述
subagent_id             string      此子代理实例的唯一标识符
subagent_type           string      子代理类型：generalPurpose、explore、shell 等
task                    string      分配给子代理的任务描述（写入日志前固定脱敏为 "..."）
parent_conversation_id  string      父级代理会话的对话 ID
tool_call_id            string      触发该子代理的工具调用 ID
subagent_model          string      子代理将使用的模型
is_parallel_worker      boolean     此子代理是否作为并行工作线程运行
git_branch              string(opt) 子代理要操作的 Git 分支（如适用）
#>
class R2eHookSubagentStartInputBody {
  [string]$subagent_id
  [string]$subagent_type
  [string]$task
  [string]$parent_conversation_id
  [string]$tool_call_id
  [string]$subagent_model
  [bool]$is_parallel_worker
  [string]$git_branch
  [hashtable]$others

  R2eHookSubagentStartInputBody() {
    $this.is_parallel_worker = $false
  }

  [string] ToJsonString() {
    $h = @{
      subagent_id            = $this.subagent_id
      subagent_type          = $this.subagent_type
      task                   = $this.task
      parent_conversation_id = $this.parent_conversation_id
      tool_call_id           = $this.tool_call_id
      subagent_model         = $this.subagent_model
      is_parallel_worker     = $this.is_parallel_worker
      git_branch             = $this.git_branch
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
    return $head, ([R2eHookSubagentStartInputBody]::new())
  }

  if (-not $head.IsValidJson) {
    $inst = [R2eHookSubagentStartInputBody]::new()
    Set-HookFallbackJsonQuotedField $inst subagent_id $bodyStr -Convert { param($cap) Get-PrettyUuid -Id $cap }
    Set-HookFallbackJsonQuotedField $inst subagent_type $bodyStr
    Set-HookFallbackJsonQuotedField $inst task $bodyStr -Convert { param($cap) '...' }
    Set-HookFallbackJsonQuotedField $inst parent_conversation_id $bodyStr -Convert { param($cap) Get-PrettyUuid -Id $cap }
    Set-HookFallbackJsonQuotedField $inst tool_call_id $bodyStr -Convert { param($cap) Get-PrettyUuid -Id $cap }
    Set-HookFallbackJsonQuotedField $inst subagent_model $bodyStr
    Set-HookFallbackJsonBoolField $inst is_parallel_worker $bodyStr
    Set-HookFallbackJsonQuotedField $inst git_branch $bodyStr
    $inst.others = @{ _errorMessage = "invalid json" }
    return $head, $inst
  }

  try {
    $obj = $bodyStr | ConvertFrom-Json
    $inst = [R2eHookSubagentStartInputBody]::new()
    if ($obj.PSObject.Properties["subagent_id"]) {
      $inst.subagent_id = Get-PrettyUuid -Id ([string]$obj.subagent_id)
      $obj.PSObject.Properties.Remove("subagent_id")
    }
    if ($obj.PSObject.Properties["subagent_type"]) {
      $inst.subagent_type = [string]$obj.subagent_type
      $obj.PSObject.Properties.Remove("subagent_type")
    }
    if ($obj.PSObject.Properties["task"]) {
      $inst.task = '...'
      $obj.PSObject.Properties.Remove("task")
    }
    if ($obj.PSObject.Properties["parent_conversation_id"]) {
      $inst.parent_conversation_id = Get-PrettyUuid -Id ([string]$obj.parent_conversation_id)
      $obj.PSObject.Properties.Remove("parent_conversation_id")
    }
    if ($obj.PSObject.Properties["tool_call_id"]) {
      $inst.tool_call_id = Get-PrettyUuid -Id ([string]$obj.tool_call_id)
      $obj.PSObject.Properties.Remove("tool_call_id")
    }
    if ($obj.PSObject.Properties["subagent_model"]) {
      $inst.subagent_model = [string]$obj.subagent_model
      $obj.PSObject.Properties.Remove("subagent_model")
    }
    if ($obj.PSObject.Properties["is_parallel_worker"]) {
      $inst.is_parallel_worker = [bool]$obj.is_parallel_worker
      $obj.PSObject.Properties.Remove("is_parallel_worker")
    }
    if ($obj.PSObject.Properties["git_branch"]) {
      $inst.git_branch = [string]$obj.git_branch
      $obj.PSObject.Properties.Remove("git_branch")
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
    $inst = [R2eHookSubagentStartInputBody]::new()
    $inst.others = @{ _errorMessage = "invalid json" }
    return $head, $inst
  }
}

function Build-HookResponse {
  <#
    生成传给 Cursor hook 的应答 JSON 字符串（不写 stdout）；调用方对返回值自行 Write-Output。
    默认：permission 放行。
  #>
  $payload = @{
    permission   = "allow"
    user_message = "ok"
  }
  return ($payload | ConvertTo-Json -Compress)
}

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
$response = Build-HookResponse
Write-Output $response
exit 0


