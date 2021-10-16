#!/bin/bash

################################################################################
# Windows FFmpeg cross-compile build script
################################################################################
#
# This script file can be included in build scripts for Windows or run directly
#
################################################################################

# Halt on errors
set -eE

_patch_product() {
    cd "${PRODUCT_FOLDER}"

    set +eE
    check_git
    set -eE

    step "Apply patches..."
    apply_patch "${CHECKOUT_DIR}/CI/windows/patches/ffmpeg/ffmpeg_flvdec.patch" "2e73d9296c3190a9e395c1e0dfe98e9b12df40e5960dc27d5cd19c7e8d8695ab"
    git add .
    git commit -m "Fix decoding of certain malformed FLV files"

    git cherry-pick 1f7b527194a2a10c334b0ff66ec0a72f4fe65e08 \
        f9d6addd60b3f9ac87388fe4ae0dc217235af81d \
        79d907774d59119dcfd1c04dae97b52890aec3ec \
        8d823e6005febef23ca10ccd9d8725e708167aeb \
        952fd0c768747a0f910ce8b689fd23d7c67a51f8 \
        d7e2a2bb35e394287b3e3dc27744830bf0b7ca99 \
        3def315c5c3baa26c4f6b7ac4622aa8a3bfb46f8 \
        f8990c5f414d4575415e2a3981c3b142222ca3d4 \
        fee4cafbf52f81ffd6ad7ed4fd0a8096f8791886 \
        b96bc946f219fbd28cffc1efea78fd42f34148ec \
        006744bdbd83d98bc71cb041d9551bf6a64b45a2 \
        aab9133d919bec4af54a06216d8629ebe4fb8f74 \
        c112fae6603f8be33cf1ee2ae390ec939812f473 \
        86a7b77b60488758e0c080882899c32c4a5ee017 \
        7cc7680a802c1eee9e334a0653f2347e9c0922a4 \
        449e984192d94ac40713e9217871c884657dc79d \
        290a35aefed250a797449c34d2f9e5af0c4e006a \
        6e95ce8cc9ae30e0e617e96e8d7e46a696b8965e \
        e9b35a249d224b2a93ffe45a1ffb7448972b83f3 \
        7c59e1b0f285cd7c7b35fcd71f49c5fd52cf9315 \
        86f5fd471d35423e3bd5c9d2bd0076b14124faee \
        fb0304fcc9f79a4c9cbdf347f20f484529f169ba
}

_build_product() {
    ensure_dir "${PRODUCT_FOLDER}"

    step "Configure (${ARCH})..."

    PKG_CONFIG_PATH="${BUILD_DIR}/lib/pkgconfig" \
        LDFLAGS="-L${BUILD_DIR}/lib -static-libgcc" \
        CFLAGS="-I${BUILD_DIR}/include -I${CHECKOUT_DIR}/windows_build_temp/pthread-win32" \
        CPPFLAGS="-I${BUILD_DIR}/include -I${CHECKOUT_DIR}/windows_build_temp/pthread-win32" \
        ./configure \
        --enable-gpl \
        --disable-programs \
        --disable-doc \
        --arch=$WIN_CROSS_TARGET \
        --enable-shared \
        --enable-nvenc \
        --enable-amf \
        --enable-libx264 \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libsrt \
        --disable-debug \
        --cross-prefix=$WIN_CROSS_TOOL_PREFIX-w64-mingw32- \
        --target-os=mingw32 \
        --pkg-config=pkg-config \
        --prefix="${BUILD_DIR}" \
        --disable-postproc \
        --enable-schannel

    step "Build (${ARCH})..."
    make -j$PARALLELISM
}

_install_product() {
    cd "${PRODUCT_FOLDER}"

    step "Install..."
    make install
}

build-ffmpeg-main() {
    PRODUCT_NAME="${PRODUCT_NAME:-ffmpeg}"

    if [ -z "${_RUN_OBS_BUILD_SCRIPT}" ]; then
        CHECKOUT_DIR="$(/usr/bin/git rev-parse --show-toplevel)"
        source "${CHECKOUT_DIR}/CI/include/build_support.sh"
        source "${CHECKOUT_DIR}/CI/include/build_support_windows_cross.sh"

        _check_parameters $*
        _build_checks
    fi

    PRODUCT_PROJECT="FFmpeg"
    PRODUCT_REPO="ffmpeg"
    PRODUCT_FOLDER="ffmpeg"

    if [ -z "${INSTALL}" ]; then
        _add_ccache_to_path

        _build_setup_git
        _build
   else
        _install_product
    fi
}

build-ffmpeg-main $*
