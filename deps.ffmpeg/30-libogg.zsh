autoload -Uz log_debug log_error log_info log_status log_output

## Dependency Information
local name='libogg'
local version='1.3.5'
local url='https://github.com/xiph/ogg.git'
local hash=fa80aae9d50096160f2b56ada35527d7aee3f746

## Build Steps
setup() {
  log_info "Setup (%F{3}${target}%f)"
  setup_dep ${url} ${hash}
}

clean() {
  cd ${dir}

  if [[ ${clean_build} -gt 0 && -d build_${arch} ]] {
    log_info "Clean build directory (%F{3}${target}%f)"

    rm -rf build_${arch}
  }
}

patch() {
  autoload -Uz apply_patch

  log_info "Patch (%F{3}${target}%f)"

  cd ${dir}

  local patch
  local _target
  local _url
  local _hash
  for patch (${patches}) {
    read _target _url _hash <<< "${patch}"

    if [[ ${_target} == "${target%%-*}" ]] apply_patch ${_url} ${_hash}
  }
}

config() {
  autoload -Uz mkcd progress

  local _onoff=(OFF ON)

  args=(
    ${cmake_flags}
    -DINSTALL_DOCS=OFF
    -DBUILD_TESTING=OFF
    -DBUILD_SHARED_LIBS="${_onoff[(( shared_libs + 1 ))]}"
  )

  log_info "Config (%F{3}${target}%f)"
  cd ${dir}
  log_debug "CMake configuration options: ${args}'"
  progress cmake -S . -B build_${arch} -G Ninja ${args}
}

build() {
  autoload -Uz mkcd progress

  log_info "Build (%F{3}${target}%f)"

  cd ${dir}

  args=(
    --build build_${arch}
    --config ${config}
  )

  if (( _loglevel > 1 )) args+=(--verbose)

  cmake ${args}
}

install() {
  autoload -Uz progress

  log_info "Install (%F{3}${target}%f)"

  args=(
    --install build_${arch}
    --config ${config}
  )

  if (( _loglevel > 1 )) args+=(--verbose)

  cd ${dir}
  progress cmake ${args}
}

fixup() {
  cd ${dir}

  log_info "Fixup (%F{3}${target}%f)"

  local strip_tool
  local -a strip_files

  case ${target} {
    macos*)
      if (( shared_libs )) {
        local -a dylib_files=(${target_config[output_dir]}/lib/libogg*.dylib(.))

        autoload -Uz fix_rpaths && fix_rpaths ${dylib_files}

        if [[ ${config} == Release ]] dsymutil ${dylib_files}
        strip_tool=strip
        strip_files=(${dylib_files})
      } else {
        rm -rf -- ${target_config[output_dir]}/lib/libogg*.(dylib|dSYM)(N)
      }
      ;;
    linux-*)
      if (( shared_libs )) {
        strip_tool=strip
        strip_files=(${target_config[output_dir]}/lib/libogg.so.*(.))
      } else {
        rm -rf -- ${target_config[output_dir]}/lib/libogg.so.*(N)
      }
      ;;
    windows-*)
      if (( shared_libs )) {
        autoload -Uz create_importlibs
        create_importlibs ${target_config[output_dir]}/bin/libogg*.dll

        strip_tool=${target_config[cross_prefix]}-w64-mingw32-strip
        strip_files=(${target_config[output_dir]}/bin/libogg*.dll(.))
      } else {
        rm -rf -- ${target_config[output_dir]}/bin/libogg*.dll(N)
      }
      ;;
  }

  rm -rf ${target_config[output_dir]}/lib/cmake/Ogg
  if (( #strip_files )) && [[ ${config} == (Release|MinSizeRel) ]] ${strip_tool} -x ${strip_files}
}
