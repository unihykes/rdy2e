param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: afterMCPExecution
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
