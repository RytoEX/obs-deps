#!/bin/bash

################################################################################
# Windows zlib cross-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

# Halt on errors
set -eE

_fixup_libs() {
    mv "${BUILD_DIR}"/lib/libzlib.dll.a "${BUILD_DIR}"/lib/libz.dll.a
    mv "${BUILD_DIR}"/lib/libzlibstatic.a "${BUILD_DIR}"/lib/libz.a
    cp ../win32/zlib.def "${BUILD_DIR}"/bin
    $WIN_CROSS_TOOL_PREFIX-w64-mingw32-dlltool -m $WIN_CROSS_MVAL -d ../win32/zlib.def -l "${BUILD_DIR}"/bin/zlib.lib -D "${BUILD_DIR}"/bin/zlib.dll

    cd "${BUILD_DIR}"
    apply_patch "${CHECKOUT_DIR}/CI/windows/patches/zlib/zlib-include-zconf.patch" "e7534bbf425d4670757b329eebb7c997e4ab928030c7479bdd8fc872e3c6e728"
}

_patch_product() {
    cd "${PRODUCT_FOLDER}"

    step "Apply patches..."
    apply_patch "${CHECKOUT_DIR}/CI/windows/patches/zlib/zlib-disable-shared-lib-prefix.patch" "ed1e5f301827046e13071d836beb8e701de1fdbfdde5ba58c70fd779b81713c8"
}

_build_product() {
    ensure_dir "${PRODUCT_FOLDER}/build_${ARCH}"

    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=$WIN_CROSS_TOOL_PREFIX-w64-mingw32-gcc \
        -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}" \
        -DINSTALL_PKGCONFIG_DIR="${BUILD_DIR}"/lib/pkgconfig \
        -DCMAKE_RC_COMPILER=$WIN_CROSS_TOOL_PREFIX-w64-mingw32-windres \
        -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -Wl,--strip-debug"

    make -j$PARALLELISM
}

_install_product() {
    cd "${PRODUCT_FOLDER}/build_${ARCH}"

    step "Install (${ARCH})..."
    make install

    _fixup_libs
}

build-zlib-main() {
    PRODUCT_NAME="${PRODUCT_NAME:-zlib}"

    if [ -z "${_RUN_OBS_BUILD_SCRIPT}" ]; then
        CHECKOUT_DIR="$(/usr/bin/git rev-parse --show-toplevel)"
        source "${CHECKOUT_DIR}/CI/include/build_support.sh"
        source "${CHECKOUT_DIR}/CI/include/build_support_windows_cross.sh"

        _check_parameters $*
        _build_checks
    fi

    PRODUCT_PROJECT="madler"
    PRODUCT_REPO="zlib"
    PRODUCT_FOLDER="${PRODUCT_REPO}"

    if [ -z "${INSTALL}" ]; then
        _add_ccache_to_path

        _build_setup_git
        _build
    else
        _install_product
    fi
}

build-zlib-main $*
