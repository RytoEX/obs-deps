Param(
    [Switch]$Help,
    [Switch]$Quiet,
    [Switch]$Verbose,
    [Switch]$NoChoco,
    [Switch]$Package,
    [Switch]$SkipDependencyChecks,
    [Switch]$BuildInstaller,
    [Switch]$CombinedArchs,
    [String]$BuildDirectory = "build",
    [String]$BuildArch = (Get-CimInstance CIM_OperatingSystem).OSArchitecture,
    [String]$BuildConfiguration = "RelWithDebInfo"
)

##############################################################################
# Windows OBS build script
##############################################################################
#
# This script contains all steps necessary to:
#
#   * Build OBS required dependencies
#   * Create 64-bit and 32-bit variants
#
# Parameters:
#   -Help                   : Print usage help
#   -Quiet                  : Suppress most build process output
#   -Verbose                : Enable more verbose build process output
#   -SkipDependencyChecks   : Skip dependency checks
#   -NoChoco                : Skip automatic dependency installation
#                             via Chocolatey
#   -BuildDirectory         : Directory to use for builds
#                             Default: Win64 on 64-bit systems
#                                      Win32 on 32-bit systems
#   -BuildArch              : Build architecture to use (32bit or 64bit)
#   -BuildConfiguration     : Build configuration to use
#                             Default: RelWithDebInfo
#   -CombinedArchs          : Create combined packages and installer
#                             (64-bit and 32-bit) - Default: off
#   -Package                : Prepare folder structure for installer creation
#
##############################################################################

$ErrorActionPreference = "Stop"

$_RunObsBuildScript = $true
$ProductName = "obs-deps"

$CheckoutDir = git rev-parse --show-toplevel
$DepsBuildDir = "${CheckoutDir}/../obs-build-dependencies"

. ${CheckoutDir}/CI/include/build_support_windows.ps1

$ObsBuildDependencies = @(
    @('mbedtls', '523f0554b6cdc7ace5d360885c3f5bbcc73ec0e8')
)

function Build-OBS-Deps-Main {
    Ensure-Directory ${CheckoutDir}
    Write-Step "Fetching version tags..."
    & git fetch origin --tags
    $GitBranch = git rev-parse --abbrev-ref HEAD
    $GitHash = git rev-parse --short HEAD
    $ErrorActionPreference = "SilentlyContinue"
    $GitTag = git describe --tags --abbrev=0
    $ErrorActionPreference = "Stop"

    if (Test-Path variable:BUILD_FOR_DISTRIBUTION) {
        $VersionString = "${GitTag}"
    } else {
        $VersionString = "${GitTag}-${GitHash}"
    }

    $FileName = "${ProductName}-${VersionString}"

    if ($CombinedArchs) {
        if (!(Test-Path env:obsInstallerTempDir)) {
            $Env:obsInstallerTempDir = "${CheckoutDir}/install_temp"
        }

        if (!$SkipDependencyChecks) {
            Install-Dependencies -NoChoco
        }
    } else {
        if (!$SkipDependencyChecks) {
            Install-Dependencies -NoChoco
        }
    }

    Foreach ($Dependency in $ObsBuildDependencies) {
        if ($Dependency -is [system.array]) {
            $DepName = $Dependency[0]
            $DepVersion = $Dependency[1]
        }
        Remove-Item -Path Function:Build-Product,
            Function:Patch-Product,
            Function:Install-Product

        Trap { Caught-Error "${DepName}" }

        Write-Step "Build dependency ${DepName}..."
        . ${CheckoutDir}/CI/windows/build_${DepName}.ps1
    }

    if ($Package) {
        Package-OBS -CombinedArchs:$CombinedArchs
    }

    Write-Info "All done!"
}

## MAIN SCRIPT FUNCTIONS ##
function Print-Usage {
    Write-Host "build-windows.ps1 - Build script for ${ProductName}"
    $Lines = @(
        "Usage: ${MyInvocation.MyCommand.Name}",
        "-Help                    : Print this help",
        "-Quiet                   : Suppress most build process output"
        "-Verbose                 : Enable more verbose build process output"
        "-SkipDependencyChecks    : Skip dependency checks - Default: off",
        "-NoChoco                 : Skip automatic dependency installation via Chocolatey - Default: on",
        "-BuildDirectory          : Directory to use for builds - Default: build64 on 64-bit systems, build32 on 32-bit systems",
        "-BuildArch               : Build architecture to use (32bit or 64bit) - Default: local architecture",
        "-BuildConfiguration      : Build configuration to use - Default: RelWithDebInfo",
        "-CombinedArchs           : Create combined packages and installer (64-bit and 32-bit) - Default: off"
        "-Package                 : Prepare folder structure for installer creation"
    )
    $Lines | Write-Host
}

if($Help) {
    Print-Usage
    exit 0
}

Build-OBS-Deps-Main
