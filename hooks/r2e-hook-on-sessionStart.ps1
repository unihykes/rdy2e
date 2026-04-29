<# 
Hook: sessionStart
鍦ㄥ垱寤烘柊鐨?composer 浼氳瘽鏃惰皟鐢ㄣ€傛 hook 浠ュ嵆鍙戝嵆蹇樻柟寮忚繍琛岋紱agent 寰幆涓嶄細绛夊緟鍏跺畬鎴愶紝涔熶笉浼氬己鍒惰姹傞樆濉炲紡鍝嶅簲銆?浣跨敤姝?hook 鏉ヨ缃細璇濅笓灞炵幆澧冨彉閲忔垨娉ㄥ叆棰濆涓婁笅鏂囥€?
杈撳叆瀛楁	绫诲瀷	鎻忚堪
session_id	string	姝や細璇濈殑鍞竴鏍囪瘑绗?(涓?conversation_id 鐩稿悓)
is_background_agent	boolean	璇ヤ細璇濇槸鍚庡彴 agent 浼氳瘽杩樻槸浜や簰寮忎細璇?composer_mode	string (optional)	composer 鍚姩鏃剁殑妯″紡 (渚嬪 "agent"銆?ask"銆?edit")

杈撳嚭瀛楁	绫诲瀷	鎻忚堪
env	object (optional)	涓烘浼氳瘽璁剧疆鐨勭幆澧冨彉閲忋€傚鍚庣画鎵€鏈?hook 鐨勬墽琛屽潎鍙敤
additional_context	string (optional)	瑕佹坊鍔犲埌瀵硅瘽鍒濆绯荤粺涓婁笅鏂囦腑鐨勯澶栦笂涓嬫枃
#>

param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

function Edit-HookInputBody {
  # sessionStart：将 JSON body 中的 session_id 截成第一段（与 conversation_id 短前缀对齐）。
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )
  if ([string]::IsNullOrWhiteSpace($Body)) {
    return $Body
  }
  try {
    $obj = $Body | ConvertFrom-Json
    if ($obj.PSObject.Properties["session_id"] -and $obj.session_id -is [string]) {
      $sid = [string]$obj.session_id
      if (-not [string]::IsNullOrWhiteSpace($sid)) {
        $obj.session_id = ($sid -split "-", 2)[0]
      }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 20)
  }
  catch {
    return $Body
  }
}

function Build-HookResponse {
  # 默认发送空对象 {}，表示不改变环境与上下文；可按需传入 -Env / -AdditionalContext。
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
  return ($out | ConvertTo-Json -Compress -Depth 20)
}

Set-HookOutputUtf8
$head, $body = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -Body $body
Log-HookEvent -Head $head -Body $body -IsValidJson $head.IsValidJson

#usage: $response = Build-HookResponse -Env @{a=1} -AdditionalContext "session_start"; Write-Output $response
$response = Build-HookResponse
Write-Output $response
exit 0


