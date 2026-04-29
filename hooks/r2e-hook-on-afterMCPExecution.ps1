param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: afterMCPExecution
Set-HookOutputUtf8
$head, $body = Get-HookInputHeadAndBody
$body = Edit-HookInputBody -Head $head -Body $body
Log-HookEvent -Head $head -Body $body -IsValidJson $head.IsValidJson
Write-HookAllowResponse
exit 0


