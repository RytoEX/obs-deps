#/bin/bash

# make directories
rm -rf win64
mkdir win64
cd win64
mkdir bin
mkdir include
mkdir lib
cd ..
mkdir -p win64/lib/pkgconfig

# set build prefix
WORKDIR=$PWD
PREFIX=$PWD/win64
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

# set variables
SKIP_PROMPTS=true
PARALLELISM=$(nproc)


#---------------------------------


# start mbedTLS
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build mbedtls..." key
fi

# download mbedTLS
curl --retry 5 -L -o mbedtls-2.24.0.tar.gz https://github.com/ARMmbed/mbedtls/archive/v2.24.0.tar.gz
tar -xf mbedtls-2.24.0.tar.gz
mv mbedtls-2.24.0 mbedtls

# build mbedTLS
# Enable the threading abstraction layer and use an alternate implementation
sed -i -e "s/\/\/#define MBEDTLS_THREADING_C/#define MBEDTLS_THREADING_C/" \
-e "s/\/\/#define MBEDTLS_THREADING_ALT/#define MBEDTLS_THREADING_ALT/" mbedtls/include/mbedtls/config.h
cp -p patch/mbedtls/threading_alt.h mbedtls/include/mbedtls/threading_alt.h


mkdir -p mbedtlsbuild/win64
cd mbedtlsbuild/win64
rm -rf *
cmake ../../mbedtls -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -Wl,--strip-debug" -DUSE_SHARED_MBEDTLS_LIBRARY=ON -DUSE_STATIC_MBEDTLS_LIBRARY=OFF -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF
make -j$PARALLELISM
x86_64-w64-mingw32-dlltool -z mbedtls.orig.def --export-all-symbols library/libmbedtls.dll
x86_64-w64-mingw32-dlltool -z mbedcrypto.orig.def --export-all-symbols library/libmbedcrypto.dll
x86_64-w64-mingw32-dlltool -z mbedx509.orig.def --export-all-symbols library/libmbedx509.dll
grep "EXPORTS\|mbedtls" mbedtls.orig.def > mbedtls.def
grep "EXPORTS\|mbedtls" mbedcrypto.orig.def > mbedcrypto.def
grep "EXPORTS\|mbedtls" mbedx509.orig.def > mbedx509.def
sed -i -e "/\\t.*DATA/d" -e "/\\t\".*/d" -e "s/\s@.*//" mbedtls.def
sed -i -e "/\\t.*DATA/d" -e "/\\t\".*/d" -e "s/\s@.*//" mbedcrypto.def
sed -i -e "/\\t.*DATA/d" -e "/\\t\".*/d" -e "s/\s@.*//" mbedx509.def
x86_64-w64-mingw32-dlltool -z mbedtls.def --export-all-symbols library/libmbedtls.dll
x86_64-w64-mingw32-dlltool -z mbedcrypto.def --export-all-symbols library/libmbedcrypto.dll
x86_64-w64-mingw32-dlltool -z mbedx509.def --export-all-symbols library/libmbedx509.dll
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d mbedtls.def -l $PREFIX/bin/mbedtls.lib -D library/libmbedtls.dll
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d mbedcrypto.def -l $PREFIX/bin/mbedcrypto.lib -D library/libmbedcrypto.dll
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d mbedx509.def -l $PREFIX/bin/mbedx509.lib -D library/libmbedx509.dll
make install
cd ../..

mv $PREFIX/lib/*.dll $PREFIX/bin

# create pkgconfig files for mbedTLS
cat > $PKG_CONFIG_PATH/mbedtls.pc <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedtls
Description:
Version: 1.0.0
Requires:
Conflicts:
Libs: -L\${libdir} -lmbedtls
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF

cat > $PKG_CONFIG_PATH/mbedcrypto.pc <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedcrypto
Description:
Version: 1.0.0
Requires:
Conflicts:
Libs: -L\${libdir} -lmbedcrypto
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF

cat > $PKG_CONFIG_PATH/mbedx509.pc <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: mbedx509
Description:
Version: 1.0.0
Requires:
Conflicts:
Libs: -L\${libdir} -lmbedx509
Cflags: -I\${includedir} -I\${includedir}/mbedtls
EOF


#---------------------------------


# pthread-win32
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build pthread-win32..." key
fi

# download pthread-win32
git clone https://github.com/GerHobbelt/pthread-win32.git

# build pthread-win32
cd pthread-win32
git checkout 19fd5054b29af1b4e3b3278bfffbb6274c6c89f5
make DESTROOT=$PREFIX CROSS=x86_64-w64-mingw32- realclean GC-small-static
cp libpthreadGC2.a $PREFIX/lib
cd ..


#---------------------------------


# libsrt
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build libsrt..." key
fi

# download libsrt
curl --retry 5 -L -o srt-v1.4.2.tar.gz https://github.com/Haivision/srt/archive/v1.4.2.tar.gz
tar -xf srt-v1.4.2.tar.gz
mv srt-1.4.2 srt

# patch libsrt
cd srt
patch -p1 < ../patch/libsrt/libsrt-minsizerel.patch
cd ..

# build libsrt
mkdir -p srtbuild/win64
cd srtbuild/win64
rm -rf *
cmake ../../srt -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DUSE_ENCLIB=mbedtls -DENABLE_APPS=OFF -DENABLE_STATIC=OFF -DENABLE_SHARED=ON -DCMAKE_C_FLAGS="-I$WORKDIR/pthread-win32" -DCMAKE_CXX_FLAGS="-I$WORKDIR/pthread-win32" -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -Wl,--strip-debug" -DPTHREAD_LIBRARY="$PREFIX/lib/libpthreadGC2.a" -DPTHREAD_INCLUDE_DIR="$WORKDIR/pthread-win32" -DUSE_OPENSSL_PC=OFF -DCMAKE_BUILD_TYPE=MinSizeRel
make -j$PARALLELISM
x86_64-w64-mingw32-strip -w --keep-symbol=srt* libsrt.dll
make install
cd ../..


#---------------------------------


# x264
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build x264..." key
fi

# download and prep x264
git clone https://code.videolan.org/videolan/x264.git
cd x264
git checkout d198931a63049db1f2c92d96c34904c69fde8117

# build x264
x264_api="$(grep '#define X264_BUILD' < x264.h | sed 's/^.* \([1-9][0-9]*\).*$/\1/')"
make clean
LDFLAGS="-static-libgcc" ./configure --enable-shared --disable-avs --disable-ffms --disable-gpac --disable-interlaced --disable-lavf --cross-prefix=x86_64-w64-mingw32- --host=x86_64-pc-mingw32 --prefix="$PREFIX"
make -j$PARALLELISM
make install
x86_64-w64-mingw32-dlltool -z $PREFIX/bin/x264.orig.def --export-all-symbols $PREFIX/bin/libx264-$x264_api.dll
grep "EXPORTS\|x264" $PREFIX/bin/x264.orig.def > $PREFIX/bin/x264.def
rm -f $PREFIX/bin/x264.orig.def
sed -i -e "/\\t.*DATA/d" -e "/\\t\".*/d" -e "s/\s@.*//" $PREFIX/bin/x264.def
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d $PREFIX/bin/x264.def -l $PREFIX/bin/x264.lib -D $PREFIX/bin/libx264-$x264_api.dll
cd ..


#---------------------------------


# opus
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build opus..." key
fi

# download opus
curl --retry 5 -L -O https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.3.1.tar.gz
tar -xf opus-1.3.1.tar.gz
mv opus-1.3.1 opus

# build opus
cd opus
make clean
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" LDFLAGS="-L$PREFIX/lib -static-libgcc" ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --enable-shared --enable-stack-protector=yes
make -j$PARALLELISM
make install
cd ..


#---------------------------------


# zlib
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build zlib..." key
fi

# download zlib
curl --retry 5 -L -O https://www.zlib.net/zlib-1.2.11.tar.gz
tar -xf zlib-1.2.11.tar.gz
mv zlib-1.2.11 zlib

# patch CMakeLists.txt to remove the "lib" prefix when building shared libraries
cd zlib
patch -p1 < $WORKDIR/patch/zlib/zlib-disable-shared-lib-prefix.patch

# build zlib
mkdir build64
cd build64
make clean
cmake .. -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres -DCMAKE_SHARED_LINKER_FLAGS="-static-libgcc -Wl,--strip-debug"
make -j$PARALLELISM
make install
mv $PREFIX/lib/libzlib.dll.a $PREFIX/lib/libz.dll.a
mv $PREFIX/lib/libzlibstatic.a $PREFIX/lib/libz.a
cp ../win32/zlib.def $PREFIX/bin
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d ../win32/zlib.def -l $PREFIX/bin/zlib.lib -D $PREFIX/bin/zlib.dll
cd ../..

# patch include/zconf.h
cd $PREFIX
patch -p1 < $WORKDIR/patch/zlib/zlib-include-zconf.patch
cd $WORKDIR


#---------------------------------


# libpng
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build libpng..." key
fi

# download libpng
curl --retry 5 -L -o libpng-1.6.37.tar.gz https://github.com/glennrp/libpng/archive/v1.6.37.tar.gz
tar -xf libpng-1.6.37.tar.gz
mv libpng-1.6.37 libpng

# build libpng
cd libpng
make clean
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" LDFLAGS="-L$PREFIX/lib" CPPFLAGS="-I$PREFIX/include" ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --enable-shared
make -j$PARALLELISM
make install
cd ..


#---------------------------------


# libogg
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build libogg..." key
fi

# download libogg
curl --retry 5 -L -o ogg-31bd3f2707fb7dbae539a7093ba1fc4b2b37d84e.tar.gz https://gitlab.xiph.org/xiph/ogg/-/archive/31bd3f2707fb7dbae539a7093ba1fc4b2b37d84e/ogg-31bd3f2707fb7dbae539a7093ba1fc4b2b37d84e.tar.gz
tar -xf ogg-31bd3f2707fb7dbae539a7093ba1fc4b2b37d84e.tar.gz
mv ogg-31bd3f2707fb7dbae539a7093ba1fc4b2b37d84e libogg

# build libogg
cd libogg
mkdir build64
./autogen.sh
cd build64
make clean
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" LDFLAGS="-L$PREFIX/lib -static-libgcc" CPPFLAGS="-I$PREFIX/include" ../configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --enable-shared
make -j$PARALLELISM
make install
cd ../..


#---------------------------------


# libvorbis
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build libvorbis..." key
fi

# download libvorbis
curl --retry 5 -L -o vorbis-83a82dd9296400d811b78c06e9ca429e24dd1e5c.tar.gz https://gitlab.xiph.org/xiph/vorbis/-/archive/83a82dd9296400d811b78c06e9ca429e24dd1e5c/vorbis-83a82dd9296400d811b78c06e9ca429e24dd1e5c.tar.gz
tar -xf vorbis-83a82dd9296400d811b78c06e9ca429e24dd1e5c.tar.gz
mv vorbis-83a82dd9296400d811b78c06e9ca429e24dd1e5c libvorbis

# build libvorbis
cd libvorbis
make clean
./autogen.sh
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" LDFLAGS="-L$PREFIX/lib -static-libgcc" CPPFLAGS="-I$PREFIX/include" ./configure --host=x86_64-w64-mingw32 --prefix="$PREFIX" --enable-shared --with-ogg="$PREFIX"
make -j$PARALLELISM
make install
cd ..


#---------------------------------


# libvpx
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build libvpx..." key
fi

# download libvpx
curl --retry 5 -L -o libvpx-git.tar.gz https://chromium.googlesource.com/webm/libvpx/+archive/e56e8dcd6fc9e2b04316be5144c18ca6772f6263.tar.gz
mkdir -p libvpx
tar -xf libvpx-git.tar.gz -C $PWD/libvpx

# build libvpx
cd libvpx
patch -p1 < ../patch/libvpx/libvpx-crosscompile-win-dll.patch
cd ..
mkdir -p libvpxbuild
cd libvpxbuild
make clean
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" CROSS=x86_64-w64-mingw32- LDFLAGS="-static-libgcc" ../libvpx/configure --prefix=$PREFIX --enable-vp8 --enable-vp9 --disable-docs --disable-examples --enable-shared --disable-static --enable-runtime-cpu-detect --enable-realtime-only --disable-install-bins --disable-install-docs --disable-unit-tests --target=x86_64-win64-gcc
make -j$PARALLELISM
make install
x86_64-w64-mingw32-dlltool -m i386:x86-64 -d libvpx.def -l $PREFIX/bin/vpx.lib -D $PREFIX/bin/libvpx-1.dll
cd ..

pkg-config --libs vpx


#---------------------------------


# FFmpeg
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to build FFmpeg..." key
fi

# nv-codec-headers
# download nv-codec-headers
git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
cd nv-codec-headers
git checkout 96a6db017b096ad48612890083464a7214902afa

# build nv-codec-headers
make PREFIX=$PREFIX
make PREFIX=$PREFIX install
cd ..

# AMF
# download/prep AMF
# git >= 2.25
#git clone --filter=blob:none --no-checkout https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git
#cd AMF
#git sparse-checkout set amf/public/include
#git checkout 802f92ee52b9efa77bf0d3ea8bfaed6040cdd35e
#mkdir -p $PREFIX/include/AMF
#cp -a amf/public/include/* $PREFIX/include/AMF
#cd ..

# git < 2.25
git clone https://github.com/obsproject/obs-amd-encoder.git
mkdir -p $PREFIX/include/AMF
cp -a obs-amd-encoder/AMF/amf/public/include/* $PREFIX/include/AMF

# download FFmpeg
#curl -L -o FFmpeg-n4.2.2.zip https://github.com/FFmpeg/FFmpeg/archive/n4.2.2.zip
#unzip FFmpeg-n4.2.2.zip
#mv FFmpeg-n4.2.2 ffmpeg
git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
cd ffmpeg
git checkout f9f95ceebfbd7b7f43c1b7ad34e25d366e6e2d2b

# verify git is configured
# git needs to be configured with user.email and user.name to be able to commit
# the patch below
# should make this a helper function
git_user_email=$(git config --get user.email)
if [ -z "$git_user_email" ]; then
	git config user.email "contact@obsproject.com"
fi
git_user_name=$(git config --get user.name)
if [ -z "$git_user_name" ]; then
	git config user.name "OBS Project"
fi

# patch FFmpeg
git apply ../patch/ffmpeg/ffmpeg_flvdec.patch
git add .
git commit -m "Fix decoding of certain malformed FLV files"

# apply cherry-picked commits
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

# build FFmpeg
make clean
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" LDFLAGS="-L$PREFIX/lib" CPPFLAGS="-I$PREFIX/include -I$WORKDIR/pthread-win32" ./configure --enable-gpl --disable-doc --arch=x86_64 --enable-shared --enable-nvenc --enable-amf --enable-libx264 --enable-libopus --enable-libvorbis --enable-libvpx --enable-libsrt --disable-debug --cross-prefix=x86_64-w64-mingw32- --target-os=mingw32 --pkg-config=pkg-config --prefix="$PREFIX" --disable-postproc
if [ "$SKIP_PROMPTS" != true ]; then
	read -n1 -r -p "Press any key to continue building FFmpeg..." key
fi
make -j$PARALLELISM
make install
cd ..
