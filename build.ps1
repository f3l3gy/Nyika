
[CmdletBinding()]
Param(
    [string]$Script = "build.cake",
    [string]$Target = "Default",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$Experimental,
    [Alias("DryRun","Noop")]
    [switch]$WhatIf,
    [switch]$Mono,
    [string]$PaketRepo = "fsprojects/Paket",
    [ValidatePattern('.paket$')]
    [string]$Paket = ".\.paket",
    [string]$Cake = ".\packages\tools\Cake",
    [string]$Tools = ".\packages\tools",
    [string]$Addins = ".\packages\addins",
    [string]$Modules = ".\packages\modules",
    [string]$DotNetVersion,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

$DOTNETVERSION = "2.1.4";

$PSScriptRoot = $pwd

# Should dotnet version is present?
if($DotNetVersion.IsPresent) {
    $DOTNETVERSION = $DotNetVersion;
}
else{
    $GLOBAL_JSON =  Join-Path $PSScriptRoot ".\global.json";
    if ((Test-Path $GLOBAL_JSON)){
        # Get dotnet version from global.json
        $DotNetVersion = select-string -Path .\global.json -Pattern '[\d]\.[\d]\.[\d]' | % {$_.Matches} | % {$_.Value };
    }
}

$DotNetInstallerUri = "https://raw.githubusercontent.com/dotnet/cli/v$DOTNETVERSION/scripts/obtain/dotnet-install.ps1";

###########################################################################
# INSTALL .NET CORE CLI
###########################################################################

Function Remove-PathVariable([string]$VariableToRemove)
{
    $path = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($path -ne $null)
    {
        $newItems = $path.Split(';', [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { "$($_)" -inotlike $VariableToRemove }
        [Environment]::SetEnvironmentVariable("PATH", [System.String]::Join(';', $newItems), "User")
    }

    $path = [Environment]::GetEnvironmentVariable("PATH", "Process")
    if ($path -ne $null)
    {
        $newItems = $path.Split(';', [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { "$($_)" -inotlike $VariableToRemove }
        [Environment]::SetEnvironmentVariable("PATH", [System.String]::Join(';', $newItems), "Process")
    }
}

# Get .NET Core CLI path if installed.
$FoundDotNetCliVersion = $null;
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $FoundDotNetCliVersion = dotnet --version;
}

if($FoundDotNetCliVersion -ne $DotNetVersion) {
    $InstallPath = Join-Path $PSScriptRoot ".dotnet"
    if (!(Test-Path $InstallPath)) {
        mkdir -Force $InstallPath | Out-Null;
    }

    (New-Object System.Net.WebClient).DownloadFile($DotNetInstallerUri, "$InstallPath\dotnet-install.ps1");
    & $InstallPath\dotnet-install.ps1 -Channel Current -Version $DotNetVersion -InstallDir $InstallPath;

    Remove-PathVariable "$InstallPath"
    $env:PATH = "$InstallPath;$env:PATH"
    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    $env:DOTNET_CLI_TELEMETRY_OPTOUT=1

    & dotnet --info
}


Write-Host "Preparing to run build script..."

# Should we use mono?
$UseMono = "";
if($Mono.IsPresent) {
    Write-Verbose -Message "Using the Mono based scripting engine."
    $UseMono = "-mono"
}

# Should we use the new Roslyn?
$UseExperimental = "";
if($Experimental.IsPresent -and !($Mono.IsPresent)) {
    Write-Verbose -Message "Using experimental version of Roslyn."
    $UseExperimental = "-experimental"
}

# Is this a dry run?
$UseDryRun = "";
if($WhatIf.IsPresent) {
    $UseDryRun = "-dryrun"
}

Write-Verbose -Message "Using paket for dependency management..."

###########################################################################
# INSTALL PAKET
###########################################################################

# Make sure the .paket directory exits
$PaketDir =  Join-Path $PSScriptRoot $Paket
if(!(Test-Path $PaketDir)) {
    mkdir -Force $PaketDir | Out-Null;
}

$ENV:PAKET = $PaketDir

# If paket.exe does not exits then download it using paket.bootstrapper.exe
$PAKET_EXE = Join-Path $PaketDir "paket.exe"
if (!(Test-Path $PAKET_EXE)) {
    # If paket.bootstrapper.exe exits then run it.
    $PAKET_BOOTSTRAPPER_FILE_NAME = "paket.bootstrapper.exe";

    $PAKET_BOOTSTRAPPER_EXE = Join-Path $PaketDir $PAKET_BOOTSTRAPPER_FILE_NAME

    if (!(Test-Path $PAKET_BOOTSTRAPPER_EXE)) {

        $releases = "https://api.github.com/repos/$PaketRepo/releases";

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $progressPreference = 'silentlyContinue'
        $tag = (Invoke-WebRequest -Uri $releases -UseBasicParsing | ConvertFrom-Json)[0].tag_name

        $download = "https://github.com/$PaketRepo/releases/download/$tag/$PAKET_BOOTSTRAPPER_FILE_NAME";

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest $download -Out $PAKET_BOOTSTRAPPER_EXE

        if (!(Test-Path $PAKET_BOOTSTRAPPER_EXE))
        {
            Throw "Could not find paket.bootstrapper.exe at $PAKET_BOOTSTRAPPER_EXE"
        }
    }
    Write-Verbose -Message "Found paket.bootstrapper.exe in PATH at $PAKET_BOOTSTRAPPER_EXE"

    # Download paket.exe
    Write-Verbose -Message "Running paket.bootstrapper.exe to download paket.exe"
    Invoke-Expression $PAKET_BOOTSTRAPPER_EXE

    if (!(Test-Path $PAKET_EXE)) {
        Throw "Could not find paket.exe at $PAKET_EXE"
    }
}

###########################################################################
# INSTALL THE DEPENDENCIES
###########################################################################

$PAKET_LOCK =  Join-Path $PSScriptRoot ".\paket.lock"

if (!(Test-Path $PAKET_LOCK)){
    Write-Verbose -Message "Running paket.exe install"
    Invoke-Expression "$PAKET_EXE install"
}

Write-Verbose -Message "Running paket.exe restore"
Invoke-Expression "$PAKET_EXE restore"

###########################################################################
# BOOTSTRAPPING CAKE BUILD SYSTEM
###########################################################################

# tools
if (Test-Path $Tools) {
    $ToolsDir = Resolve-Path $Tools
    $ENV:CAKE_PATHS_TOOLS =  $ToolsDir
}
else {
    Write-Verbose -Message "Could not find tools directory at $Tools"
}

# addins
if (Test-Path $Addins) {
    $AddinsDir = Resolve-Path $Addins
    $ENV:CAKE_PATHS_ADDINS = $AddinsDir
}
else {
    Write-Verbose -Message "Could not find addins directory at $Addins"
}

# modules
if (Test-Path $Modules) {
    $ModulesDir = Resolve-Path $Modules
    $ENV:CAKE_PATHS_MODULES = $ModulesDir
}
else {
    Write-Verbose -Message "Could not find modules directory at $Modules"
}

# Make sure that Cake has been installed.

$CakeDir = Join-Path $PSScriptRoot $Cake

$CAKE_EXE = Join-Path $CakeDir "Cake.exe"

if (!(Test-Path $CAKE_EXE)) {
    Throw "Could not find Cake.exe at $CAKE_EXE"
}
Write-Verbose -Message "Found Cake.exe in PATH at $CAKE_EXE"

# Start Cake
Write-Host "Running build script..."

Invoke-Expression "& `"$CAKE_EXE`" `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseMono $UseDryRun $UseExperimental $ScriptArgs"
exit $LASTEXITCODE
