################################################################################
# Windows mbedtls native-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

function _patch_product() {
    cd "${PRODUCT_FOLDER}"

    step "Apply patches..."
    apply_patch "${CHECKOUT_DIR}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-01.patch" "306b8aaee8f291cc0dbd4cbee12ea185e722469eb06b8b7113f0a60feca6bbe6"

    if [ ! -f "include\mbedtls\threading_alt.h" ]; then
        apply_patch "${CHECKOUT_DIR}\CI\windows\patches\mbedtls\mbedtls-enable-alt-threading-02.patch" "d0dde0836dc6b100edf218207feffbbf808d04b1d0065082cdc5c838f8a4a7c7"
    fi
}

function _build_product() {
    ensure_dir "${PRODUCT_FOLDER}\build_${ARCH}"

    step "Configure (${ARCH})..."
    cmake -G "Visual Studio 16 2019" \
        -A x64 \
        -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}" \
        -DUSE_SHARED_MBEDTLS_LIBRARY=OFF \
        -DUSE_STATIC_MBEDTLS_LIBRARY=ON \
        -DENABLE_PROGRAMS=OFF \
        ${QUIET:+-Wno-deprecated -Wno-dev --log-level=ERROR}
        -S "mbedtls"
        -B "mbedtls_build\64"

    Write-Step "Build (${ARCH})..."
    cmake --build "build_${ARCH}" --config "RelWithDebInfo"
}

function _install_product() {
    cd "${PRODUCT_FOLDER}/build_${ARCH}"

    Write-Step "Install (${ARCH})..."
    cmake --install "build_${ARCH}" --config "RelWithDebInfo"
}

function Build-Mbedtls-Main() {
    PRODUCT_NAME="${PRODUCT_NAME:-mbedtls}"

    if [ -z "${_RUN_OBS_BUILD_SCRIPT}" ]; then
        CHECKOUT_DIR="$(/usr/bin/git rev-parse --show-toplevel)"
        source "${CHECKOUT_DIR}/CI/include/build_support.sh"
        source "${CHECKOUT_DIR}/CI/include/build_support_windows_cross.sh"

        _check_parameters $*
        _build_checks
    fi

    NOCONTINUE=TRUE
    PRODUCT_PROJECT="ARMmbed"
    PRODUCT_REPO="mbedtls"
    PRODUCT_FOLDER="${PRODUCT_REPO}"

    if [ -z "${INSTALL}" ]; then
        _build_setup_git
        _build
    else
        _install_product
    fi
}

Build-Mbedtls-Main $*
