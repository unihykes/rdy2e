param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: afterMCPExecution
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$logEntry = Get-HookStdinLogEntryParts -RawInput $rawInput
$projectDir = Get-HookProjectDir
$head = Get-HookLogHead -Entry $logEntry
$body = $logEntry.Body
if ($logEntry.HeadFields.IsValidJson) {
  $body = Edit-HookLogBody -Body $body
}
Add-HookLogLine -ProjectDir $projectDir -Head $head -Body $body -IsValidJson $logEntry.HeadFields.IsValidJson
Write-HookAllowResponse
exit 0
