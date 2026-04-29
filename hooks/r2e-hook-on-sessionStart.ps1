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

class R2eHookSessionStartInputBody {
  [string]$session_id
  [bool]$is_background_agent
  [string]$composer_mode

  [string] ToJsonString() {
    return (@{
        session_id          = $this.session_id
        is_background_agent = $this.is_background_agent
        composer_mode       = $this.composer_mode
      } | ConvertTo-Json -Compress -Depth 20)
  }
}

function Edit-HookInputBody {
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$BodyStr
  )
  if ([string]::IsNullOrWhiteSpace($BodyStr)) {
    return $null
  }
  try {
    $obj = $BodyStr | ConvertFrom-Json
    $inst = [R2eHookSessionStartInputBody]::new()
    if ($obj.PSObject.Properties["session_id"]) {
      $sid = [string]$obj.session_id
      $inst.session_id = if (-not [string]::IsNullOrWhiteSpace($sid)) {
        ($sid -split "-", 2)[0]
      }
      else {
        $sid
      }
    }
    if ($obj.PSObject.Properties["is_background_agent"]) {
      $inst.is_background_agent = [bool]$obj.is_background_agent
    }
    if ($obj.PSObject.Properties["composer_mode"]) {
      $inst.composer_mode = [string]$obj.composer_mode
    }
    return $inst
  }
  catch {
    return $null
  }
}

function Build-HookResponse {
  # 默认发送空对象 {}，表示不改变环境与上下文；可按需传入 -Env / -AdditionalContext / -Body。
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [hashtable]$Env,
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$AdditionalContext,
    [Parameter(Mandatory = $false)]
    [R2eHookSessionStartInputBody]$Body
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
  # 预留：按 $Body（如 composer_mode / is_background_agent）填充 env 或其它应答字段。
  return ($out | ConvertTo-Json -Compress -Depth 20)
}

Set-HookOutputUtf8
$head, $bodyStr = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -BodyStr $bodyStr
$bodyLog = if ($null -ne $body) {
  $body.ToJsonString()
}
else {
  $bodyStr
}
Log-HookEvent -Head $head -BodyLog $bodyLog -IsValidJson $head.IsValidJson

#usage: $response = Build-HookResponse -Env @{a=1} -AdditionalContext "session_start" -Body $body; Write-Output $response
$response = Build-HookResponse -Body $body
Write-Output $response
exit 0


