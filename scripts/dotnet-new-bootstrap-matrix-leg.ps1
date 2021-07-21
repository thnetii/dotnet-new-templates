[CmdletBinding()]
param (
    [string]$OutputName = $ENV:TEMPLATE_OUTPUT_NAME,
    [string]$CliTemplate = $ENV:TEMPLATE_CLI_INVOKE,
    [securestring]$GithubToken = (ConvertTo-SecureString -AsPlainText $ENV:GITHUB_TOKEN)
)

while (-not $OutputName) {
    $OutputName = Read-Host -Prompt OutputName
}
while (-not $CliTemplate) {
    $CliTemplate = Read-Host -Prompt CliTemplate
}
if (-not $GithubToken) {
    $GithubToken = Read-Host -Prompt GithubToken -AsSecureString
}

$TargetDirectory = Join-Path "src" $OutputName
Write-Host "Target directory: $TargetDirectory"

Write-Host "::group::Delete files in target directory"
Remove-Item -Recurse -Force -ErrorAction Continue $TargetDirectory
Write-Host "::endgroup::"

Write-Host "::group::Invoke dotnet new $CliTemplate"
& dotnet new $CliTemplate -o $TargetDirectory
Write-Host "::endgroup::"

Write-Host "::group::Determine if changes have been made"
[string]$GitStatus = $null
& git status --porcelain | Tee-Object -Variable GitStatus
if ($GitStatus) {
    Write-Verbose "Git changes have been detected"
}
else {
    Write-Verbose "No changes have been detected"
    return
}
Write-Host "::endgroup::"
