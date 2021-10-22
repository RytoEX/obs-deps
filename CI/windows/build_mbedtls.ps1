Param(
    [Switch]$Help,
    [Switch]$Quiet,
    [Switch]$Verbose,
    [Switch]$NoChoco,
    [Switch]$Package,
    [Switch]$SkipDependencyChecks,
    [Switch]$Install,
    [String]$BuildDirectory = "build",
    [String]$BuildArch = (Get-CimInstance CIM_OperatingSystem).OSArchitecture,
    [String]$BuildConfiguration = "RelWithDebInfo"
)

################################################################################
# Windows mbedtls native-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

function Patch-Product {
    cd "${PRODUCT_FOLDER}"

    Write-Step "Apply patches..."
    Apply-Patch "${CheckoutDir}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-01.patch" "306b8aaee8f291cc0dbd4cbee12ea185e722469eb06b8b7113f0a60feca6bbe6"

    if (!(Test-Path "include\mbedtls\threading_alt.h")) {
        Apply-Patch "${CheckoutDir}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-02.patch" "d0dde0836dc6b100edf218207feffbbf808d04b1d0065082cdc5c838f8a4a7c7"
    }
}

function Build-Product {
    cd "${DepsBuildDir}"

    if ($Quiet) {
        $CMAKE_OPTS = "-Wno-deprecated -Wno-dev --log-level=ERROR"
    } else {
        $CMAKE_OPTS = ""
    }

    Write-Step "Configure (${ARCH})..."
    cmake -G "Visual Studio 16 2019" `
        -A x64 `
        -DUSE_SHARED_MBEDTLS_LIBRARY=OFF `
        -DUSE_STATIC_MBEDTLS_LIBRARY=ON `
        -DENABLE_PROGRAMS=OFF `
        "${CMAKE_OPTS}" `
        -S "mbedtls" `
        -B "mbedtls_build\${CMAKE_BITNESS}"

    Write-Step "Build (${ARCH})..."
    cmake --build "mbedtls_build\${CMAKE_BITNESS}" --config "RelWithDebInfo"
}

function Install-Product {
    cd "${DepsBuildDir}"

    Write-Step "Install (${ARCH})..."
    cmake --install "mbedtls_build\${CMAKE_BITNESS}" --config "RelWithDebInfo" --prefix "${DepsBuildDir}\${CMAKE_INSTALL_DIR}"
}

function Build-Mbedtls-Main {
    $PRODUCT_NAME = "${PRODUCT_NAME}"
    if (!${PRODUCT_NAME}) {
        Write-Output "PRODUCT_NAME is empty"
        $PRODUCT_NAME = "mbedtls"
    }
    Write-Output "PRODUCT_NAME: ${PRODUCT_NAME}"

    if (!${_RunObsDepsBuildScript}) {
        $CheckoutDir = "$(git rev-parse --show-toplevel)"
        Write-Output "PRODUCT_NAME: ${PRODUCT_NAME}"
        . "${CheckoutDir}/CI/include/build_support_windows.ps1"

        Write-Status "_RunObsDepsBuildScript is false"
        #_check_parameters $*
        Build-Checks -NoChoco:${NoChoco}
    }

    Write-Status "PRODUCT_NAME: ${PRODUCT_NAME}"
    Write-Status "CheckoutDir: ${CheckoutDir}"
    Write-Status "PRODUCT_PROJECT: ${PRODUCT_PROJECT}"
    Write-Status "PRODUCT_REPO: ${PRODUCT_REPO}"
    Write-Status "PRODUCT_HASH: ${PRODUCT_HASH}"
    $NOCONTINUE = $true
    $PRODUCT_PROJECT = "ARMmbed"
    $PRODUCT_REPO = "mbedtls"
    $PRODUCT_FOLDER = "${PRODUCT_REPO}"

    if (!$Install) {
        Build-Setup-GitHub
        Build
    } else {
        Install-Product
    }
}

Build-Mbedtls-Main
