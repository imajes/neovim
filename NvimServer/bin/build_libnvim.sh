#!/bin/bash
set -Eeuo pipefail

readonly target=${target:?"arm64 or x86_64: you can only build the same target as your machine"}

download_gettext() {
  local tag
  tag=$(cat "./NvimServer/Resources/nvim-version-for-gettext.txt")
  readonly tag
  local -r archive_folder="./NvimServer/build"
  rm -rf "${archive_folder}" && mkdir -p ${archive_folder}

  local -r archive_file_name="gettext-${target}.tar.bz2"
  local -r archive_file_path="${archive_folder}/${archive_file_name}"

  curl -o "${archive_file_path}" -L "https://github.com/qvacua/neovim/releases/download/${tag}/gettext-${target}.tar.bz2"

  pushd "${archive_folder}" >/dev/null
    tar xf "${archive_file_name}"
  popd >/dev/null

  local -r third_party_folder="./NvimServer/third-party"
  rm -rf "${third_party_folder}" && mkdir -p "${third_party_folder}"

  mv "${archive_folder}/lib" "${third_party_folder}"
  mv "${archive_folder}/include" "${third_party_folder}"
}

build_libnvim() {
  local -r deployment_target=$1

  # Brew's gettext does not get sym-linked to PATH
  export PATH="/opt/homebrew/opt/gettext/bin:/usr/local/opt/gettext/bin:${PATH}"

  make \
    SDKROOT="$(xcrun --show-sdk-path)" \
    MACOSX_DEPLOYMENT_TARGET="${deployment_target}" \
    CMAKE_EXTRA_FLAGS="-DGETTEXT_SOURCE=CUSTOM -DCMAKE_OSX_DEPLOYMENT_TARGET=${deployment_target}" \
    DEPS_CMAKE_FLAGS="-DCMAKE_OSX_DEPLOYMENT_TARGET=${deployment_target} -DCMAKE_CXX_COMPILER=$(xcrun -find c++)" \
    CMAKE_BUILD_TYPE=Release \
    libnvim
}

package() {
  local -r package_stage_folder_name="libnvim-${target}"
  local -r package_stage_folder="./build/${package_stage_folder_name}"
  mkdir -p "${package_stage_folder}"

  cp ./build/lib/libnvim.a "${package_stage_folder}"
  cp ./.deps/usr/lib/*.a "${package_stage_folder}"

  pushd ./build >/dev/null
    tar cjf "libnvim-${target}.tar.bz2" "${package_stage_folder_name}"
  popd >/dev/null

  echo "Packaged to $(realpath ./build/libnvim-${target}.tar.bz2)"
}

main() {
  # This script is located in /NvimServer/bin and we have to go to /
  pushd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null

  download_gettext

  echo "### Building libnvim"
  local deployment_target
  deployment_target=$(cat "./NvimServer/Resources/${target}_deployment_target.txt")
  readonly deployment_target

  make distclean
  build_libnvim "${deployment_target}"

  package

  popd >/dev/null
  echo "### Built libnvim"
}

main