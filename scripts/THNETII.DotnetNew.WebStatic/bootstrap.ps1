[CmdletBinding()]
param (
    [string]$OutputName = $ENV:TEMPLATE_OUTPUT_NAME,
    [string]$CliTemplate = $ENV:TEMPLATE_CLI_INVOKE,
    [string]$GithubContextJson = $ENV:GITHUB_CONTEXT
)

$TargetDirectory = Join-Path "src" $OutputName

$BootstrapJsFile = Join-Path $PSScriptRoot "bootstrap.js"
& node $BootstrapJsFile
