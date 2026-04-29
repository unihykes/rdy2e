param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: sessionEnd
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$stdinPayload = Get-HookStdinPayload -RawInput $rawInput
$projectDir = Get-HookProjectDir
$linePrefix = Format-HookStdinContextLinePrefix -InputPayload $stdinPayload
$payload = $stdinPayload.Payload
if ($stdinPayload.Context.IsValidJson) {
  $payload = Edit-HookStdinPayload -Payload $payload
}
Add-HookEventsFileLine -ProjectDir $projectDir -LinePrefix $linePrefix -Payload $payload -IsValidJson $stdinPayload.Context.IsValidJson
Write-HookAllowResponse
exit 0
