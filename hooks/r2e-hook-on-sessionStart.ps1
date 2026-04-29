param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: sessionStart
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$logData = Get-HookLogData -RawInput $rawInput
$projectDir = Get-HookProjectDir
Write-HookLog -LogData $logData -ProjectDir $projectDir
$null = Normalize-HookRawInputForDebug -RawInput $rawInput
Write-HookAllowResponse
exit 0
