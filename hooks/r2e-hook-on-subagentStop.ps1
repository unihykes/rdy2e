param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: subagentStop
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$context, $payload = Get-HookStdinPayload -RawInput $rawInput
$projectDir = Get-HookProjectDir
$linePrefix = Format-HookStdinContextLinePrefix -Context $context
$payload = Invoke-HookStdinPayloadEdit -Context $context -Payload $payload
Add-HookEventsFileLine -ProjectDir $projectDir -LinePrefix $linePrefix -Payload $payload -IsValidJson $context.IsValidJson
Write-HookAllowResponse
exit 0
