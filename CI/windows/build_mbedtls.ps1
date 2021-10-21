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
    Apply-Patch "${CHECKOUT_DIR}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-01.patch" "306b8aaee8f291cc0dbd4cbee12ea185e722469eb06b8b7113f0a60feca6bbe6"

    if (!Test-Path "include\mbedtls\threading_alt.h") {
        Apply-Patch "${CHECKOUT_DIR}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-02.patch" "d0dde0836dc6b100edf218207feffbbf808d04b1d0065082cdc5c838f8a4a7c7"
    }
}

function Build-Product {
    Ensure-Directory "${PRODUCT_FOLDER}\build_${ARCH}"

    if ("${QUIET}") {
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
        -B "mbedtls_build\64"

    Write-Step "Build (${ARCH})..."
    cmake --build "build_${ARCH}" --config "RelWithDebInfo"
}

function Install-Product {
    cd "${PRODUCT_FOLDER}/build_${ARCH}"

    Write-Step "Install (${ARCH})..."
    cmake --install "build_${ARCH}" --config "RelWithDebInfo" --prefix "${BUILD_DIR}"
}

function Build-Mbedtls-Main {
    $PRODUCT_NAME = "${PRODUCT_NAME:-mbedtls}"

    if (!"${_RUN_OBS_BUILD_SCRIPT}") {
        $CHECKOUT_DIR = "$(/usr/bin/git rev-parse --show-toplevel)"
        . "${CHECKOUT_DIR}/CI/include/build_support_windows.ps1"

        #_check_parameters $*
        Build-Checks
    }

    $NOCONTINUE = $true
    $PRODUCT_PROJECT = "ARMmbed"
    $PRODUCT_REPO = "mbedtls"
    $PRODUCT_FOLDER = "${PRODUCT_REPO}"

    if (!"${INSTALL}") {
        Build-Setup-GitHub
        Build
    } else {
        Install-Product
    }
}

Build-Mbedtls-Main $*
