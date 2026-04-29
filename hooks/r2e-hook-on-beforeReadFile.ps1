param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: beforeReadFile
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$context, $payload = Get-HookStdinPayload -RawInput $rawInput
$projectDir = Get-HookProjectDir
$linePrefix = Format-HookStdinContextLinePrefix -Context $context
if ($context.IsValidJson) {
  $payload = Edit-HookStdinPayload -Payload $payload
}
Add-HookEventsFileLine -ProjectDir $projectDir -LinePrefix $linePrefix -Payload $payload -IsValidJson $context.IsValidJson
Write-HookAllowResponse
exit 0
