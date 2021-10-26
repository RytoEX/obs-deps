Param(
    [Switch]$Help = $(if (Test-Path variable:Help) { $Help }),
    [Switch]$Quiet = $(if (Test-Path variable:Quiet) { $Quiet }),
    [Switch]$Verbose = $(if (Test-Path variable:Verbose) { $Verbose }),
    [Switch]$NoChoco = $(if (Test-Path variable:NoChoco) { $NoChoco }),
    [Switch]$SkipDependencyChecks = $(if (Test-Path variable:SkipDependencyChecks) { $SkipDependencyChecks }),
    [Switch]$Install = $(if (Test-Path variable:Install) { $Install }),
    [String]$BuildDirectory = "build",
    [ValidateSet("32-bit", "64-bit")]
    [String]$BuildArch = (Get-CimInstance CIM_OperatingSystem).OSArchitecture,
    [ValidateSet("Release", "RelWithDebInfo", "MinSizeRel", "Debug")]
    [String]$BuildConfiguration = "RelWithDebInfo"
)

################################################################################
# Windows LuaJIT native-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

function Build-Product {
    cd "${DepsBuildDir}"

    if ($Quiet) {
        $CMAKE_OPTS = "-Wno-deprecated -Wno-dev --log-level=ERROR"
    } else {
        $CMAKE_OPTS = ""
    }

    Write-Step "Build (${ARCH})..."
    cmd.exe /c """${script:VcvarsFolder}\vcvars${CMAKE_BITNESS}.bat"" & cd ""${DepsBuildDir}\${ProductFolder}\src"" & msvcbuild.bat"
}

function Install-Product {
    cd "${DepsBuildDir}"

    Write-Step "Install (${ARCH})..."
    Copy-Item -Path @("${DepsBuildDir}\${ProductFolder}\src\lua51.dll", "${DepsBuildDir}\${ProductFolder}\src\luajit.lib") -Destination "${CMAKE_INSTALL_DIR}\bin"
    Copy-Item -Path "${DepsBuildDir}\${ProductFolder}\src\*.h" -Destination "${CMAKE_INSTALL_DIR}\include\luajit"
}

function Build-Luajit-Main {
    $ProductName = "${ProductName}"
    if (!${ProductName}) {
        $ProductName = "luajit"
    }

    if (!${_RunObsDepsBuildScript}) {
        $CheckoutDir = "$(git rev-parse --show-toplevel)"
        . "${CheckoutDir}/CI/include/build_support_windows.ps1"

        Build-Checks
    }

    $ProductProject = "luajit"
    $ProductRepo = "luajit"
    $ProductFolder = "${ProductRepo}"

    if (!$Install) {
        Build-Setup-GitHub
        Build
    } else {
        Install-Product
    }
}

Build-Luajit-Main