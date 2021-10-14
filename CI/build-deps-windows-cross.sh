#!/bin/bash

##############################################################################
# Windows cross-compiled dependencies build script
##############################################################################
#
# This script compiles all the FFmpeg dependencies required to build OBS
#
# Parameters:
#   -h, --help                     : Print usage help
#   -q, --quiet                    : Suppress most build process output
#   -v, --verbose                  : Enable more verbose build process output
#   -a, --architecture             : Specify build architecture
#                                    (default: x86_64, alternative: x86)"
#
##############################################################################

# Halt on errors
set -eE

## SET UP ENVIRONMENT ##
_RUN_OBS_BUILD_SCRIPT=TRUE
PRODUCT_NAME="obs-deps"
REQUIRED_DEPS=(
    "mbedtls 2.24.0 523f0554b6cdc7ace5d360885c3f5bbcc73ec0e8"
    "pthread-win32 2.10.0.0 19fd5054b29af1b4e3b3278bfffbb6274c6c89f5"
    "libsrt 1.4.2 50b7af06f3a0a456c172b4cb3aceafa8a5cc0036"
    "libx264 r3020 d198931a63049db1f2c92d96c34904c69fde8117"
)

## MAIN SCRIPT FUNCTIONS ##
obs-deps-build-main() {
    QMAKE_QUIET=TRUE
    CHECKOUT_DIR="$(/usr/bin/git rev-parse --show-toplevel)"
    BUILD_DIR="${CHECKOUT_DIR}/../obs-prebuilt-dependencies"
    source "${CHECKOUT_DIR}/CI/include/build_support.sh"
    source "${CHECKOUT_DIR}/CI/include/build_support_windows_cross.sh"
    _check_parameters $*

    _build_checks

    ensure_dir "${CHECKOUT_DIR}"

    FILE_NAME="windows-cross-deps-${CURRENT_DATE}-${ARCH:-${CURRENT_ARCH}}.tar.xz"
    ORIG_PATH="${PATH}"

    for DEPENDENCY in "${REQUIRED_DEPS[@]}"; do
        unset -f _build_product
        unset -f _patch_product
        unset -f _install_product
        unset NOCONTINUE
        PATH="${ORIG_PATH}"

        set -- ${DEPENDENCY}
        trap "caught_error ${DEPENDENCY}" ERR

        if [ "${1}" = "swig" ]; then
            PCRE_VERSION="8.44"
            PCRE_HASH="19108658b23b3ec5058edc9f66ac545ea19f9537234be1ec62b714c84399366d"
        fi

        PRODUCT_NAME="${1}"
        PRODUCT_VERSION="${2}"
        PRODUCT_HASH="${3}"

        source "${CHECKOUT_DIR}/CI/windows/build_${1}.sh"
    done

    cd "${CHECKOUT_DIR}/windows/obs-dependencies-${ARCH}"

    step "Cleanup unnecessary files..."
    find . \( -type f -or -type l \) \( -name "*.la" -or -name "*.a" \) | xargs rm
    rm -rf ./lib
    rm -rf ./share
    cp -R "${CHECKOUT_DIR}/licenses" .

    step "Create archive ${FILE_NAME}"
    XZ_OPT=-T0 tar -cJf "${FILE_NAME}" *

    mv ${FILE_NAME} ..

    cleanup
}

obs-deps-build-main $*
