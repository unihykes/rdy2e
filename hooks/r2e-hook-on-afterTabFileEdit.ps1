param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

<#
// 输入
{
  "file_path": "<absolute path>",
  "edits": [
    {
      "old_string": "<search>",
      "new_string": "<replace>",
      "range": {
        "start_line_number": 10,
        "start_column": 5,
        "end_line_number": 10,
        "end_column": 20
      },
      "old_line": "<line before edit>",
      "new_line": "<line after edit>"
    }
  ]
}
#>
class R2eHookAfterTabFileEditInputBody {
  [string]$file_path
  [System.Object[]]$edits
  [hashtable]$others

  R2eHookAfterTabFileEditInputBody() {
    $this.edits = @()
  }

  [string] ToJsonString() {
    $h = @{
      file_path = $this.file_path
      edits     = $this.edits
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
    return $head, ([R2eHookAfterTabFileEditInputBody]::new())
  }

  if (-not $head.IsValidJson) {
    $inst = [R2eHookAfterTabFileEditInputBody]::new()
    Set-HookFallbackJsonQuotedField $inst file_path $bodyStr
    $inst.others = @{ _errorMessage = "invalid json" }
    return $head, $inst
  }

  try {
    $obj = $bodyStr | ConvertFrom-Json
    $inst = [R2eHookAfterTabFileEditInputBody]::new()

    if ($obj.PSObject.Properties["file_path"]) {
      $v = $obj.file_path
      if ($null -ne $v) {
        $inst.file_path = [string]$v
      }
      $obj.PSObject.Properties.Remove("file_path")
    }
    if ($obj.PSObject.Properties["edits"]) {
      $inst.edits = ConvertFrom-R2eHookFileEditsForLog -Edits $obj.edits
      $obj.PSObject.Properties.Remove("edits")
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
    $inst = [R2eHookAfterTabFileEditInputBody]::new()
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


# Hook: afterTabFileEdit
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





