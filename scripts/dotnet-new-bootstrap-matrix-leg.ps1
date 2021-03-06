#Requires -Version 6.0
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

$BootstrapScriptDirectory = Join-Path $PSScriptRoot $OutputName
$TargetDirectory = Join-Path "src" $OutputName
Write-Host "Target directory: $TargetDirectory"

Write-Host "::group::preBoostrap: $OutputName"
$PreBootstrapScriptFile = Join-Path $BootstrapScriptDirectory "preBootstrap.ps1"
if (Test-Path -PathType Leaf $PreBootstrapScriptFile) {
    & $PreBootstrapScriptFile -ErrorAction $ErrorActionPreference
}
Write-Host "::endgroup"

Write-Host "::group::Delete files in target directory"
Remove-Item -Recurse -Force -ErrorAction Continue $TargetDirectory
Write-Host "::endgroup::"

Write-Host "::group::Invoke dotnet new $CliTemplate"
& dotnet new $CliTemplate -o $TargetDirectory
Write-Host "::endgroup::"

Write-Host "::group::boostrap: $OutputName"
$BootstrapScriptFile = Join-Path $BootstrapScriptDirectory "bootstrap.ps1"
if (Test-Path -PathType Leaf $BootstrapScriptFile) {
    & $BootstrapScriptFile -ErrorAction $ErrorActionPreference
}
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

Write-Host "::group::Make commit and pull request"
Write-Host "Request workflow id for current run with ID: $GithubActionsRunId"
[PSObject]$GithubActionsRunInfo = Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Get `
    "$($GithubContext.api_url)/repos/$($GithubContext.repository)/actions/runs/$($GithubContext.run_id)" `
    -Headers @{ Accept = "application/vnd.github.v3+json" }
[long]$WorkflowId = $GithubActionsRunInfo.workflow_id
Write-Host "Determined workflow id: $WorkflowId"
$TargetBranch = "workflows/workflow$WorkflowId/$OutputName"

# Configure Git
& git config --local user.name "github-actions[bot]"
& git config --local user.email "github-actions[bot]"

# Git commit
& git add $TargetDirectory
& git commit -m "Executed workflow $($GithubContext.workflow) for template with name $OutputName" `
    -m "Part of [workflow run $($GithubContext.run_id)]($($GithubActionsRunInfo.html_url))"

# Check for existing PR and branch
[PSObject]$GithubExistingPulls = Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Get `
    "$($GithubContext.api_url)/repos/$($GithubContext.repository)/pulls" `
    -Headers @{ Accept = "application/vnd.github.v3+json" } -Body @{
    "state" = "open";
    "head"  = $TargetBranch
}
[long]$PullRequestNumber = 0L
$GitHubPrTitle = "Update template content for $OutputName"
$GitHubPrBody = @"
While running the scheduled bootstrapping code for the template named ``$OutputName``
the GitHub actions run detected that the code in the repository changed. This is
indicative of that the .NET CLI template named ``$CliTemplate`` has been updated
and therefore produced a different output than before.

The changes shown here were created as part of a GitHub Action Workflow run. See
$($GithubActionsRunInfo.html_url) for more details on that run.
"@
if ($GithubExistingPulls) {
    [PSObject]$GitHubPullRequestInfo = $GithubExistingPulls[0]
    [long]$PullRequestNumber = $GitHubPullRequestInfo.number
    & git push -f origin "HEAD:$TargetBranch"
    [void](Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Patch `
            "$($GithubContext.api_url)/repos/$($GithubContext.repository)/pulls/$PullRequestNumber" `
            -ContentType "application/json; charset=utf-8" -Body (@{
                title = $GitHubPrTitle;
                body  = $GitHubPrBody;
            } | ConvertTo-Json) -Headers @{ Accept = "application/vnd.github.v3+json" })
}
else {
    & git push -f origin "HEAD:$TargetBranch"
    [PSObject]$GitHubPullRequestInfo = Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Post `
        "$($GithubContext.api_url)/repos/$($GithubContext.repository)/pulls" `
        -ContentType "application/json; charset=utf-8" -Body (@{
            title = $GitHubPrTitle;
            head  = $TargetBranch;
            base  = $GithubContext.ref;
            body  = $GitHubPrBody;
        } | ConvertTo-Json) -Headers @{ Accept = "application/vnd.github.v3+json" }
    [long]$PullRequestNumber = $GitHubPullRequestInfo.number
}

[void](Invoke-RestMethod -Authentication Bearer -Token $GithubToken -Method Post `
        "$($GithubContext.api_url)/repos/$($GithubContext.repository)/issues/$PullRequestNumber/labels" `
        -ContentType "application/json; charset=utf-8" -Body (@{
            labels = @(
                "template-update", "dotnet-new"
            )
        } | ConvertTo-Json) -Headers @{ Accept = "application/vnd.github.v3+json" })
Write-Host "::endgroup::"
