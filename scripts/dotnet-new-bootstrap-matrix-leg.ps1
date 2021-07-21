[CmdletBinding()]
param (
    [string]$OutputName = $ENV:TEMPLATE_OUTPUT_NAME,
    [string]$CliTemplate = $ENV:TEMPLATE_CLI_INVOKE,
    [securestring]$GithubToken = (ConvertTo-SecureString -AsPlainText $ENV:GITHUB_TOKEN),
    [string]$GithubContextJson = $ENV:GITHUB_CONTEXT
)

while (-not $OutputName) {
    $OutputName = Read-Host -Prompt OutputName
}
while (-not $CliTemplate) {
    $CliTemplate = Read-Host -Prompt CliTemplate
}
[psobject]$GithubContext = if ($GithubContextJson) {
    ConvertFrom-Json $GithubContextJson
}
else { $null }
if (-not $GithubToken) {
    $GithubToken = ConvertTo-SecureString -AsPlainText $GithubContext.token
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
    Write-Host "Git changes have been detected"
}
else {
    Write-Host "No changes have been detected"
    return
}
Write-Host "::endgroup::"

Write-Host "Request workflow id for current run with ID: $GithubActionsRunId"
[PSObject]$GithubActionsRunInfo = $null
Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Get `
    "https://api.github.com/repos/$($GithubContext.repository)/actions/runs/$($GithubContext.run_id)" `
    -Headers @{ Accept = "application/vnd.github.v3+json" } `
    | Tee-Object -Variable GithubActionsRunInfo
[long]$WorkflowId = $GithubActionsRunInfo.workflow_id
Write-Host "Determined workflow id: $WorkflowId"
$TargetBranch = "workflows/workflow$WorkflowId/$OutputName"

# TODO: Check for existing PR and branch

Write-Host "::group::Push changes to a branch"
[PSObject]$GithubMeInfo = $null
Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Get `
    "https://api.github.com/user" `
    -Headers @{ Accept = "application/vnd.github.v3+json" } `
    | Tee-Object -Variable GithubMeInfo
Write-Host "::endgroup::"
