param()

. (Join-Path $PSScriptRoot "hook-common.ps1")

# 入口脚本仅负责调用公共能力，便于后续多个 hook 复用。
Set-HookOutputUtf8
$rawInput = Read-HookRawInput
$logData = Get-HookLogData -RawInput $rawInput
$projectDir = Get-HookProjectDir
Write-HookLog -LogData $logData -ProjectDir $projectDir
$null = Normalize-HookRawInputForDebug -RawInput $rawInput
Write-HookAllowResponse
exit 0
