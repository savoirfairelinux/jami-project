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

TOP="$(pwd)"
INSTALL="${TOP}/install"

if $global; then
    BUILDDIR="build-global"
else
    BUILDDIR="build-local"
fi

cd "${TOP}/daemon"
DAEMON="$(pwd)"
cd contrib
mkdir -p native
cd native
../bootstrap
make -j2
cd "${DAEMON}"
./autogen.sh
if $global; then
  ./configure --without-dbus
else
  ./configure --without-dbus --prefix="${INSTALL}/daemon"
fi
make -j$(nproc)
make_install $global

cd "${TOP}/lrc"
mkdir -p ${BUILDDIR}
cd ${BUILDDIR}
if $global; then
  cmake .. -DCMAKE_BUILD_TYPE=Debug $static
else
  cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" -DRING_BUILD_DIR="${DAEMON}/src" $static
fi
make
make_install $global

cd "${TOP}/client-macosx"
mkdir -p ${BUILDDIR}
cd ${BUILDDIR}
if $global; then
  cmake .. -DENABLE_SPARKLE=false  $static
else
  cmake .. -DENABLE_SPARKLE=false -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient" -DCMAKE_INSTALL_PREFIX="${INSTALL}/client-macosx"  $static
fi
make
make_install $global
