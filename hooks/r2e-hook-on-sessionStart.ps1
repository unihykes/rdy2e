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
  # 瀵?stdin 瑙ｆ瀽鍚庣殑 Body锛圝SON 瀛楃涓诧級鍋氫簩娆″鐞?  param(
    [Parameter(Mandatory = $true)]
    [R2eHookInputHead]$Head,
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body
  )
  try {
    $obj = $Body | ConvertFrom-Json
    if ($obj.PSObject.Properties["session_id"] -and $obj.session_id -is [string]) {
      $sid = [string]$obj.session_id
      if (-not [string]::IsNullOrWhiteSpace($sid)) {
        $obj.session_id = ($sid -split "-", 2)[0]
      }
    }
    return ($obj | ConvertTo-Json -Compress -Depth 20)
  } catch {
    return $Body
  }
}

function Write-HookAllowResponse {
  # 榛樿鍙戦€佺┖瀵硅薄 {}锛岃〃绀轰笉鏀瑰彉鐜涓庝笂涓嬫枃銆?  [CmdletBinding()]
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
$head, $body = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -Head $head -Body $body
Log-HookEvent -Head $head -Body $body -IsValidJson $head.IsValidJson

#usage: Write-HookAllowResponse -Env @{a=1} -AdditionalContext "session_start"
Write-HookAllowResponse
exit 0


