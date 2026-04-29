param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")


function Edit-HookInputBody {
  <#
    各 hook 可在 dot-source 本文件之后重新定义同名函数，对 Body（JSON 字符串）做二次处理。
    默认实现为 no-op，直接返回 Body。
  #>
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )

  return $Body
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


# Hook: preToolUse
Set-HookOutputUtf8
$head, $body = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -Body $body
Log-HookEvent -Head $head -Body $body -IsValidJson $head.IsValidJson
$response = Build-HookResponse
Write-Output $response
exit 0





