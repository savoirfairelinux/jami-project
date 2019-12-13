#!/usr/bin/env bash

# Build and install to a local prefix under this repository.
export OSTYPE

# Flags:

  # -g: install globally instead for all users
  # -s: link everything statically, no D-Bus communication. More likely to work!
  # -c: client to build
  # -p: number of processors to use
  # -u: disable use of privileges (sudo) during install

set -ex

global=false
static=''
client=''
proc='1'
priv_install=true
while getopts gsc:P:p:u OPT; do
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
    P)
      prefix="${OPTARG}"
    ;;
    p)
      proc="${OPTARG}"
    ;;
    u)
      priv_install='false'
    ;;
    \?)
      exit 1
    ;;
  esac
done

make_install() {
  if [ "$1" = "true" ] && [ "$2" != "false" ]; then
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

if [ "${global}" = "true" ]; then
    BUILDDIR="build-global"
else
    BUILDDIR="build-local"
fi

cd "${TOP}/daemon"
DAEMON="$(pwd)"
cd contrib
mkdir -p native
cd native
if [ "${prefix+set}" ]; then
    ../bootstrap --prefix="${prefix}"
else
    ../bootstrap
fi
make
cd "${DAEMON}"
./autogen.sh

#keep shared Lib on MAC OSX
if [[ "$OSTYPE" != "darwin"* ]]; then
    sharedLib="--disable-shared"
fi

if [ "${global}" = "true" ]; then
  if [ "${prefix+set}" ]; then
    ./configure $sharedLib $CONFIGURE_FLAGS --prefix="${prefix}"
  else
    ./configure $sharedLib $CONFIGURE_FLAGS
  fi
else
  ./configure $sharedLib $CONFIGURE_FLAGS --prefix="${INSTALL}/daemon"
fi
make -j"${proc}"
make_install "${global}" "${priv_install}"

cd "${TOP}/lrc"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
if [ "${global}" = "true" ]; then
  if [ "${prefix+set}" ]; then
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="${prefix}" $static
  else
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" -DCMAKE_BUILD_TYPE=Debug $static
  fi
else
  cmake ..  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
            -DRING_BUILD_DIR="${DAEMON}/src" $static
fi
make -j"${proc}"
make_install "${global}"  "${priv_install}"

cd "${TOP}/${client}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
if [ "${global}" = "true" ]; then
  if [ "${prefix+set}" ]; then
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" -DCMAKE_INSTALL_PREFIX="${prefix}" $static
  else
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" $static
  fi
else
  cmake ..  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}" \
            -DRINGTONE_DIR="${INSTALL}/daemon/share/ring/ringtones" \
            -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient" $static
fi
make -j"${proc}"
make_install "${global}" "${priv_install}"
