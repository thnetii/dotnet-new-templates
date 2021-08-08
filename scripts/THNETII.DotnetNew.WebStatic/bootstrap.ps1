[CmdletBinding()]
param (
    [string]$OutputName = $ENV:TEMPLATE_OUTPUT_NAME,
    [string]$CliTemplate = $ENV:TEMPLATE_CLI_INVOKE,
    [string]$GithubContextJson = $ENV:GITHUB_CONTEXT
)

$TargetDirectory = Join-Path "src" $OutputName

### Fix dynamic random port allocation in Properties/launchSettings.json
$PropertiesDirectory = Join-Path $TargetDirectory "Properties"
$LaunchSettingsJsonFilePath = Join-Path $PropertiesDirectory "launchSettings.json"

& sed -i -E 's/\"applicationUrl\":\s*\"http\:\/\/localhost\:([0-9]+)\"/\"applicationUrl\"\: \"http\:\/\/localhost:iisApplicationUrlPort\"/' $LaunchSettingsJsonFilePath
& sed -i -E 's/\"sslPort\":\s*([0-9]+)/\"sslPort\"\: 9998979695/' $LaunchSettingsJsonFilePath
