[CmdletBinding()]
param (
    [string]$OutputName = $ENV:TEMPLATE_OUTPUT_NAME,
    [string]$CliTemplate = $ENV:TEMPLATE_CLI_INVOKE,
    [string]$GithubContextJson = $ENV:GITHUB_CONTEXT
)

$TargetDirectory = Join-Path "src" $OutputName

# Properties/launchSettings.json
$PropertiesLaunchSettingsJsonFilePath = Join-Path (Join-Path $TargetDirectory "Properties") "launchSettings.json"
$PropertiesLaunchSettingsJsonText = Get-Content $PropertiesLaunchSettingsJsonFilePath -ErrorAction SilentlyContinue
if (-not $PropertiesLaunchSettingsJsonText) {
    $PropertiesLaunchSettingsJsonText = "null"
}
$ENV:PREBOOTSTRAP_PROPERTIES_LAUNCHSETTINGS_JSON = $PropertiesLaunchSettingsJsonText
