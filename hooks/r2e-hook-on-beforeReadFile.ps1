param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

<#
// 输入
{
  "file_path": "<absolute path>",
  "content": "<file contents>",
  "attachments": [
    {
      "type": "file" | "rule",
      "file_path": "<absolute path>"
    }
  ]
}
输入字段	类型	描述
file_path	string	将要读取的文件的绝对路径
content	string	文件的完整内容
attachments	array	与提示关联的上下文附件。每个条目都包含一个 type ("file" 或 "rule") 和一个 file_path。
#>
class R2eHookBeforeReadFileInputBody {
  [string]$file_path
  [string]$content
  [System.Object[]]$attachments
  [hashtable]$others

  R2eHookBeforeReadFileInputBody() {
    $this.attachments = @()
  }

  [string] ToJsonString() {
    $h = @{
      file_path   = $this.file_path
      content     = $this.content
      attachments = $this.attachments
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
    return $head, ([R2eHookBeforeReadFileInputBody]::new())
  }

  if (-not $head.IsValidJson) {
    $inst = [R2eHookBeforeReadFileInputBody]::new()
    Set-HookFallbackJsonQuotedField $inst file_path $bodyStr
    Set-HookFallbackJsonQuotedField $inst content $bodyStr -Convert { param($cap) '...' }
    $inst.others = @{ _errorMessage = "invalid json" }
    return $head, $inst
  }

  try {
    $obj = $bodyStr | ConvertFrom-Json
    $inst = [R2eHookBeforeReadFileInputBody]::new()

    if ($obj.PSObject.Properties["file_path"]) {
      $v = $obj.file_path
      if ($null -ne $v) {
        $inst.file_path = [string]$v
      }
      $obj.PSObject.Properties.Remove("file_path")
    }
    if ($obj.PSObject.Properties["content"]) {
      $inst.content = '...'
      $obj.PSObject.Properties.Remove("content")
    }
    if ($obj.PSObject.Properties["attachments"]) {
      $inst.attachments = ConvertFrom-R2eHookAttachmentsForLog -Attachments $obj.attachments
      $obj.PSObject.Properties.Remove("attachments")
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
    $inst = [R2eHookBeforeReadFileInputBody]::new()
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
    permission = "allow"
    user_message = "ok"
  }
  return ($payload | ConvertTo-Json -Compress)
}


# Hook: beforeReadFile
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





