param()

. (Join-Path $PSScriptRoot "r2e-hook-common.ps1")

# Hook: afterAgentThought
Set-HookOutputUtf8
$head, $body = Get-HookInputHeadAndBody
$projectDir = Get-HookProjectDir
$linePrefix = Format-HookInputHeadLinePrefix -Head $head
$body = Invoke-HookInputBodyEdit -Head $head -Body $body
Add-HookEventsFileLine -ProjectDir $projectDir -LinePrefix $linePrefix -Body $body -IsValidJson $head.IsValidJson
Write-HookAllowResponse
exit 0
