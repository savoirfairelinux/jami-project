#!/usr/bin/env bash

# Build and install to a local prefix under this repository.

# Flags:

  # -g: install globally instead for all users

set -ex

global=false
while getopts g OPT; do
  case "$OPT" in
    g)
      global='true'
    ;;
    \?)
      exit 1
    ;;
  esac
done

make_install() {
  if $1; then
    sudo make install
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
  cmake .. -DCMAKE_BUILD_TYPE=Debug
else
  cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" -DRING_BUILD_DIR="${DAEMON}/src"
fi
# If we don't use -DENABLE_STATIC here and on the client,
# we'd have to point LD_LIBRARY_PATH to the directory containing libringclient.so
make
make_install $global

cd "${TOP}/client-gnome"
mkdir -p build
cd build
if $global; then
  cmake ..
else
  cmake .. -DCMAKE_INSTALL_PREFIX="${INSTALL}/client-gnome" -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient"
fi
make
make_install $global
