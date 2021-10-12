#!/bin/bash

##############################################################################
# Windows mbedtls build script
##############################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
##############################################################################

# Halt on errors
set -eE

_patch_product() {
    cd "${PRODUCT_FOLDER}"

    step "Apply patches..."
    apply_patch "${CHECKOUT_DIR}/CI/windows/patches/mbedtls-enable-alt-threading.patch" "6100d0dad3f1ba12d74a2833b60d52921bc0794e1361b92560387310883d45d8"
}

_build_product() {
    cd "${PRODUCT_FOLDER}"

    step "Configure (${ARCH})..."
    cmake -S . -B build_${ARCH} ${CMAKE_CCACHE_OPTIONS} \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=$toolprefix-w64-mingw32-gcc \
        -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}" \
        -DCMAKE_RC_COMPILER=$toolprefix-w64-mingw32-windres \
        -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -Wl,--strip-debug" \
        -DUSE_SHARED_MBEDTLS_LIBRARY=ON \
        -DUSE_STATIC_MBEDTLS_LIBRARY=OFF \
        -DENABLE_PROGRAMS=OFF \
        -DENABLE_TESTING=OFF \
        ${QUIET:+-Wno-deprecated -Wno-dev --log-level=ERROR}

    step "Build (${ARCH})..."
    cmake --build build_${ARCH} --config "Release"
}

_install_product() {
    cd "${PRODUCT_FOLDER}"

    step "Install (${ARCH})..."
    cmake --install build_${ARCH} --config "Release"
    _install_pkgconfig
}

_install_pkgconfig() {
    mkdir -p "${BUILD_DIR}/lib/pkgconfig"

    bash -c "cat <<'EOF' > '${BUILD_DIR}/lib/pkgconfig/mbedcrypto.pc'
prefix='${BUILD_DIR}'
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: mbedcrypto
Description: lightweight crypto and SSL/TLS library.
Version: ${PRODUCT_VERSION:-${CI_PRODUCT_VERSION}}
Requires:
Conflicts:
Libs: -L\${libdir} -lmbedcrypto
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF"

    bash -c "cat <<'EOF' > '${BUILD_DIR}/lib/pkgconfig/mbedtls.pc'
prefix='${BUILD_DIR}'
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: mbedtls
Description: lightweight crypto and SSL/TLS library.
Version: ${PRODUCT_VERSION:-${CI_PRODUCT_VERSION}}
Requires.private: mbedx509
Conflicts:
Libs: -L\${libdir} -lmbedtls
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF"

    bash -c "cat <<'EOF' > '${BUILD_DIR}/lib/pkgconfig/mbedx509.pc'
prefix='${BUILD_DIR}'
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: mbedx509
Description: The mbedTLS X.509 library
Version: ${PRODUCT_VERSION:-${CI_PRODUCT_VERSION}}
Requires.private: mbedcrypto
Conflicts:
Libs: -L\${libdir} -lmbedx509
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF"
}

build-mbedtls-main() {
    PRODUCT_NAME="${PRODUCT_NAME:-mbedtls}"

    if [ -z "${_RUN_OBS_BUILD_SCRIPT}" ]; then
        CHECKOUT_DIR="$(/usr/bin/git rev-parse --show-toplevel)"
        source "${CHECKOUT_DIR}/CI/include/build_support.sh"
        source "${CHECKOUT_DIR}/CI/include/build_support_windows.sh"

        _check_parameters $*
        _build_checks
    fi

    NOCONTINUE=TRUE
    PRODUCT_URL="https://github.com/ARMmbed/mbedtls/archive/refs/tags/mbedtls-${PRODUCT_VERSION:-${CI_PRODUCT_VERSION}}.tar.gz"
    PRODUCT_FILENAME="$(basename "${PRODUCT_URL}")"
    PRODUCT_FOLDER="mbedtls-mbedtls-${PRODUCT_VERSION:-${CI_PRODUCT_VERSION}}"

    if [ -z "${INSTALL}" ]; then
        _build_setup
        _build
    else
        _install_product
    fi
}

build-mbedtls-main $*
