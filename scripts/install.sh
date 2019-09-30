#!/usr/bin/env bash

# Build and install to a local prefix under this repository.
export OSTYPE

# Flags:

  # -g: install globally instead for all users
  # -s: link everything statically, no D-Bus communication. More likely to work!
  # -c: client to build
  # -p: number of processors to use

set -ex

global=false
static=''
client=''
proc=''
while getopts gsc:p: OPT; do
  case "$OPT" in
    g)
      global='true'
    ;;
    s)
      static='-DENABLE_STATIC=true'
    ;;
    c)
      client="${OPTARG}"
    ;;
    p)
      proc="${OPTARG}"
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
make
cd "${DAEMON}"
./autogen.sh

#keep shared Lib on MAC OSX
if [[ "$OSTYPE" != "darwin"* ]]; then
    sharedLib="--disable-shared"
fi

if $global; then
  ./configure $sharedLib $CONFIGURE_FLAGS
else
  ./configure $sharedLib $CONFIGURE_FLAGS --prefix="${INSTALL}/daemon"
fi
make -j${proc}
make_install $global

cd "${TOP}/lrc"
mkdir -p ${BUILDDIR}
cd ${BUILDDIR}
if $global; then
  cmake .. -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH -DCMAKE_BUILD_TYPE=Debug $static
else
  cmake ..  -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
            -DRING_BUILD_DIR="${DAEMON}/src" $static
fi
make -j${proc}
make_install $global

cd "${TOP}/${client}"
mkdir -p ${BUILDDIR}
cd ${BUILDDIR}
if $global; then
  cmake .. -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH $static
else
  cmake ..  -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}" \
            -DRINGTONE_DIR="${INSTALL}/daemon/share/ring/ringtones" \
            -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient" $static
fi
make -j${proc}
make_install $global
