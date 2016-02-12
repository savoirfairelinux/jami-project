#!/usr/bin/env bash

# Build and install to a local prefix under this repository.

# Flags:

  # -g: install globally instead for all users
  # -s: link everything statically, no D-Bus communication. More likely to work!

set -ex

global=false
static=''
while getopts gs OPT; do
  case "$OPT" in
    g)
      global='true'
    ;;
    s)
      static='-DENABLE_STATIC=true'
    ;;
    \?)
      exit 1
    ;;
  esac
done

make_install() {
  if $1; then
    sudo make install
    # Or else the next non-sudo install will fail, because this generates some
    # root owned files like install_manifest.txt under the build directory.
    sudo chown -R "$USER" .
  else
    make install
  fi
}

./ubuntu-15.10-dependencies.sh

TOP="$(pwd)"
INSTALL="${TOP}/install"

cd daemon
DAEMON="$(pwd)"
cd contrib
mkdir -p native
cd native
../bootstrap
make -j$(nproc)
cd "${DAEMON}"
./autogen.sh
if $global; then
  ./configure
else
  ./configure --prefix="${INSTALL}/daemon"
fi
make -j$(nproc)
make_install $global

cd "${TOP}/lrc"
mkdir -p build
cd build
if $global; then
  cmake .. -DCMAKE_BUILD_TYPE=Debug $static
else
  cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" -DRING_BUILD_DIR="${DAEMON}/src" $static
fi
make
make_install $global

cd "${TOP}/client-gnome"
mkdir -p build
cd build
if $global; then
  cmake .. $static
else
  cmake .. -DCMAKE_INSTALL_PREFIX="${INSTALL}/client-gnome" -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient" $static
fi
make
make_install $global
