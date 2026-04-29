param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: preToolUse
Set-HookOutputUtf8
$head, $body = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -Body $body
Log-HookEvent -Head $head -Body $body -IsValidJson $head.IsValidJson
$response = Build-HookResponse
Write-Output $response
exit 0




