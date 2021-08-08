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

### Create Template configuration folder
$TemplateConfigDirectory = Join-Path $TargetDirectory ".template.config"
New-Item -ItemType Directory $TemplateConfigDirectory -Force
Copy-Item (Join-Path $PSScriptRoot "template.json") -Destination (Join-Path $TemplateConfigDirectory "template.json")

### Read Startup.cs
[System.IO.FileInfo]$StatupCsFileInfo = Get-Item (Join-Path $TargetDirectory "Startup.cs")
$TempCommentLines = New-Object "System.Collections.Generic.List[string]"
$ConfigureServicesCommentLines = New-Object "System.Collections.Generic.List[string]"
$ConfigureServicesCodeLines = New-Object "System.Collections.Generic.List[string]"
$ConfigureCommentLines = New-Object "System.Collections.Generic.List[string]"
$ConfigureCodeLines = New-Object "System.Collections.Generic.List[string]"
try {
    $StartupCsReader = $StatupCsFileInfo.OpenText()
    [string]$StartupCsLine = $null
    while ($null -ne ($StartupCsReader.ReadLine() | Tee-Object -Variable StartupCsLine)) {
        $StartupCsLineTrimmed = $StartupCsLine.Trim()
        if ($StartupCsLine.StartsWith("//")) {
            [void]$TempCommentLines.Add($StartupCsLineTrimmed)
        }
        elseif ($StartupCsLineTrimmed.StartsWith("public void ConfigureServices")) {
            [void]$ConfigureServicesCommentLines.AddRange($TempCommentLines)
            [void]$TempCommentLines.Clear()
            [ValidateNotNull()][string]$StartupCsOpenCurlyLine = ""
            do {
                [ValidateNotNull()][string]$StartupCsOpenCurlyLine = $StartupCsReader.ReadLine()
            } until ("{" -eq $StartupCsOpenCurlyLine.Trim())
            [string]$IndentCurlyString = $StartupCsOpenCurlyLine.Substring(0, $StartupCsOpenCurlyLine.IndexOf("{"))
            [string]$IndentCodeString = $IndentCurlyString + "    "
            $StartupCsCloseCurlyLine = $IndentCurlyString + "}"
            [ValidateNotNull()][string]$StartupCsCodeLine = ""
            while ($true) {
                [ValidateNotNull()][string]$StartupCsCodeLine = $StartupCsReader.ReadLine()
                if ($StartupCsCodeLine.TrimEnd() -eq $StartupCsCloseCurlyLine) {
                    break
                }
                $StartupCsCodeIndent = $StartupCsCodeLine.Substring(0, $IndentCodeString.Length)
                [string]$StartupCsCodeLineUnindented = $null
                if ([string]::IsNullOrWhiteSpace($StartupCsCodeIndent)) {
                    $StartupCsCodeLineUnindented = $StartupCsCodeLine.Substring($IndentCodeString.Length)
                }
                else {
                    $StartupCsCodeLineUnindented = $StartupCsCodeLine.TrimStart()
                }
                [void]$ConfigureServicesCodeLines.Add($StartupCsCodeLineUnindented)
            }
        }
        elseif ($StartupCsLineTrimmed.StartsWith("public void Configure")) {
            [void]$ConfigureCommentLines.AddRange($TempCommentLines)
            [void]$TempCommentLines.Clear()
            [ValidateNotNull()][string]$StartupCsOpenCurlyLine = ""
            do {
                [ValidateNotNull()][string]$StartupCsOpenCurlyLine = $StartupCsReader.ReadLine()
            } until ("{" -eq $StartupCsOpenCurlyLine.Trim())
            [string]$IndentCurlyString = $StartupCsOpenCurlyLine.Substring(0, $StartupCsOpenCurlyLine.IndexOf("{"))
            [string]$IndentCodeString = $IndentCurlyString + "    "
            $StartupCsCloseCurlyLine = $IndentCurlyString + "}"
            [ValidateNotNull()][string]$StartupCsCodeLine = ""
            while ($true) {
                [ValidateNotNull()][string]$StartupCsCodeLine = $StartupCsReader.ReadLine()
                if ($StartupCsCodeLine.TrimEnd() -eq $StartupCsCloseCurlyLine) {
                    break
                }
                $StartupCsCodeIndent = $StartupCsCodeLine.Substring(0, $IndentCodeString.Length)
                [string]$StartupCsCodeLineUnindented = $null
                if ([string]::IsNullOrWhiteSpace($StartupCsCodeIndent)) {
                    $StartupCsCodeLineUnindented = $StartupCsCodeLine.Substring($IndentCodeString.Length)
                }
                else {
                    $StartupCsCodeLineUnindented = $StartupCsCodeLine.TrimStart()
                }
                [void]$ConfigureCodeLines.Add($StartupCsCodeLineUnindented)
            }
        }
        else {
            [void]$TempCommentLines.Clear()
        }
    }
}
finally {
    if ($StartupCsReader) {
        $StartupCsReader.Close()
    }
    Remove-Variable StartupCsReader
    Remove-Variable TempCommentLines
}
[void]$StatupCsFileInfo.Delete()

### Modify Program.cs
[System.IO.FileInfo]$ProgramCsFileInfo = Get-Item (Join-Path $TargetDirectory "Program.cs")
$ProgramCsLines = New-Object "System.Collections.Generic.List[string]"
try {
    $ProgramCsReader = $ProgramCsFileInfo.OpenText()
    $SkipUsingsComplete = $false
    [string]$ProgramCsLine = $null
    while ($null -ne ($ProgramCsReader.ReadLine() | Tee-Object -Variable ProgramCsLine)) {
        if (-not $SkipUsingsComplete) {
            if ($ProgramCsLine.StartsWith("using")) {
                continue # Ignore line
            }
            else {
                [void]$ProgramCsLines.AddRange([string[]](Get-Content (Join-Path $PSScriptRoot "Program.usings.txt")))
                [void]$ProgramCsLines.Add($ProgramCsLine)
                $SkipUsingsComplete = $true
            }
        }
        elseif ($ProgramCsLine.TrimStart().StartsWith("webBuilder.UseStartup<Startup>();")) {
            $IndentCurlyString = $ProgramCsLine.Substring(0, $ProgramCsLine.IndexOf("webBuilder"))
            $IndentCodeString = $IndentCurlyString + "    "
            [void]$ProgramCsLines.AddRange([string[]]@(
                "${IndentCurlyString}webBuilder.ConfigureServices(services =>",
                "${IndentCurlyString}{"
            ))
            $ConfigureServicesCommentLines | ForEach-Object {
                [void]$ProgramCsLines.Add("${IndentCodeString}$_")
            }
            $ConfigureServicesCodeLines | ForEach-Object {
                [void]$ProgramCsLines.Add("${IndentCodeString}$_")
            }
            [void]$ProgramCsLines.Add("${IndentCurlyString}});")
            [void]$ProgramCsLines.AddRange([string[]]@(
                "${IndentCurlyString}webBuilder.Configure((context, app) =>",
                "${IndentCurlyString}{"
            ))
            $ConfigureCommentLines | ForEach-Object {
                [void]$ProgramCsLines.Add("${IndentCodeString}$_")
            }
            [void]$ProgramCsLines.Add("${IndentCodeString}var env = context.HostingEnvironment;")
            $ConfigureCodeLines | ForEach-Object {
                [void]$ProgramCsLines.Add("${IndentCodeString}$_")
            }
            [void]$ProgramCsLines.Add("${IndentCurlyString}});")
        }
        else {
            [void]$ProgramCsLines.Add($ProgramCsLine)
        }
    }
}
finally {
    if ($ProgramCsReader) {
        $ProgramCsReader.Close()
    }
    Remove-Variable ProgramCsReader
}
Set-Content -LiteralPath $ProgramCsFileInfo.FullName $ProgramCsLines.ToArray() -Encoding utf8NoBOM -Force
