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
# Windows cmocka native-compile build script
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

    Write-Step "Configure (${ARCH})..."
    cmake -G "Visual Studio 16 2019" `
        -A "${CMAKE_ARCH}" `
        -DBUILD_TESTING=OFF `
        -DWITH_EXAMPLES=OFF `
        "${CMAKE_OPTS}" `
        -S "cmocka" `
        -B "cmocka_build\${CMAKE_BITNESS}"

    Write-Step "Build (${ARCH})..."
    cmake --build "cmocka_build\${CMAKE_BITNESS}" --config "${BuildConfiguration}"
}

function Install-Product {
    cd "${DepsBuildDir}"

    Write-Step "Install (${ARCH})..."
    cmake --install "cmocka_build\${CMAKE_BITNESS}" --config "${BuildConfiguration}" --prefix "${DepsBuildDir}\${CMAKE_INSTALL_DIR}"
}

function Build-Cmocka-Main {
    $ProductName = "${ProductName}"
    if (!${ProductName}) {
        $ProductName = "cmocka"
    }

    if (!${_RunObsDepsBuildScript}) {
        $CheckoutDir = "$(git rev-parse --show-toplevel)"
        . "${CheckoutDir}/CI/include/build_support_windows.ps1"

        Build-Checks
    }

    $ProductProject = "cmocka"
    $ProductRepo = "cmocka"
    $ProductFolder = "${ProductRepo}"

    if (!$Install) {
        Build-Setup-GitLab
        Build
    } else {
        Install-Product
    }
}

Build-Cmocka-Main
