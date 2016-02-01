#!/usr/bin/env bash

# Build and install to a local prefix under this repository.

set -e

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
./configure --prefix="${INSTALL}/daemon"
make -j$(nproc)
make install

cd "${TOP}/lrc"
mkdir -p build
cd build
# If we don't use -DENABLE_STATIC here and on the client,
# we'd have to point LD_LIBRARY_PATH to the directory containing libringclient.so
cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
  -DRING_BUILD_DIR="${DAEMON}/src"
make
make install

cd "${TOP}/client-gnome"
mkdir -p build
cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${INSTALL}/client-gnome" \
  -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient"
make
make install
