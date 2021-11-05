#!/usr/bin/env bash

# Build and install to a local prefix under this repository.
export OSTYPE

# Flags:

  # -g: install globally instead for all users
  # -s: link everything statically, no D-Bus communication. More likely to work!
  # -c: client to build
  # -p: number of processors to use
  # -u: disable use of privileges (sudo) during install
  # -W: disable libwrap and shared library

set -ex

# Qt_MIN_VER required for client-qt
QT5_MIN_VER="5.14"

debug=
global=false
static=''
client=''
qt5ver=''
qt5path=''
proc='1'
priv_install=true
enable_libwrap=true

while getopts gsc:dq:Q:P:p:uW OPT; do
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
    d)
      debug=true
    ;;
    q)
      qt5ver="${OPTARG}"
    ;;
    Q)
      qt5path="${OPTARG}"
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
    W)
      enable_libwrap='false'
    ;;
    \?)
      exit 1
    ;;
  esac
done

# $1: global-install?
# $2: private-install?
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

BUILD_TYPE="Release"
if [ "${debug}" = "true" ]; then
  BUILD_TYPE="Debug"
  CONFIGURE_FLAGS+=( --enable-debug)
fi

# jamid
DAEMON=${TOP}/daemon
cd "$DAEMON"

# Build the contribs.
mkdir -p contrib/native
(
    cd contrib/native
    ../bootstrap ${prefix:+"--prefix=$prefix"}
    make -j"${proc}"
)
# Disable shared if requested
if [[ "$OSTYPE" != "darwin"* ]]; then
    # Keep the shared libaries on MAC OSX.
    if [ "${enable_libwrap}" == "false" ]; then
        CONFIGURE_FLAGS+=( --disable-shared --enable-shm)
    fi
fi
# Build the daemon itself.
test -f configure || ./autogen.sh

if [ "${global}" = "true" ]; then
    ./configure "$CONFIGURE_FLAGS" ${prefix:+"--prefix=$prefix"}
else
    ./configure "$CONFIGURE_FLAGS" --prefix="${INSTALL}/daemon"
fi
make -j"${proc}" V=1
make_install "${global}" "${priv_install}"

# For the client-qt, verify system's version if no path provided
if [ "${client}" = "client-qt" ] && [ -z "$qt5path" ]; then
    sys_qt5ver=""
    if command -v qmake &> /dev/null; then
        sys_qt5ver=$(qmake -v)
    elif command -v qmake-qt5 &> /dev/null; then
        sys_qt5ver=$(qmake-qt5 -v)   # Fedora
    else
        echo "No valid Qt found"; exit 1;
    fi

    sys_qt5ver=${sys_qt5ver#*Qt version}
    sys_qt5ver=${sys_qt5ver%\ in\ *}

    installed_qt5ver=$(echo "$sys_qt5ver" | cut -d'.' -f 2)
    required_qt5ver=$(echo $QT5_MIN_VER | cut -d'.' -f 2)

    if [[ $installed_qt5ver -ge $required_qt5ver ]] ; then
        # Disable qt5path and qt5ver in order to use system's Qt
        qt5path=""
        qt5ver=""
    else
        echo "No valid Qt found"; exit 1;
    fi
fi

# libringclient
cd "${TOP}/lrc"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
# Compute LRC CMake flags
lrc_cmake_flags=(-DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}"
                 -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
                 -DQT5_VER="${qt5ver}"
                 -DQT5_PATH="${qt5path}"
                 -DENABLE_LIBWRAP="${enable_libwrap}"
                 $static)
if [ "${global}" = "true" ]; then
    lrc_cmake_flags+=(${prefix:+"-DCMAKE_INSTALL_PREFIX=$prefix"})
else
    lrc_cmake_flags+=(-DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc"
                      -DRING_BUILD_DIR="${DAEMON}/src")
fi
echo "info: Configuring LRC with flags: ${lrc_cmake_flags[*]}"
cmake .. "${lrc_cmake_flags[@]}"
make -j"${proc}" V=1
make_install "${global}" "${priv_install}"

# client
cd "${TOP}/${client}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

client_cmake_flags=(-DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
                    -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}")

if [ "${client}" = "client-qt" ]; then
    # Compute Qt client CMake flags.
    client_cmake_flags+=(-DQT5_VER="${qt5ver}"
                         -DQT5_PATH="${qt5path}")
    if [ "${global}" = "true" ]; then
        client_cmake_flags+=(${prefix:+"-DCMAKE_INSTALL_PREFIX=$prefix"}
                             $static)
    else
        client_cmake_flags+=(-DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}"
                             -DLRC="${INSTALL}/lrc")
    fi
else
    # Compute GNOME client CMake flags.
    client_cmake_flags+=($static)
    if [ "${global}" = "true" ]; then
        client_cmake_flags+=(${prefix:+"-DCMAKE_INSTALL_PREFIX=$prefix"})
    else
        client_cmake_flags+=(
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}"
            -DRINGTONE_DIR="${INSTALL}/daemon/share/jami/ringtones"
            -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient")
    fi
fi
echo "info: Configuring $client client with flags: ${client_cmake_flags[*]}"
cmake .. "${client_cmake_flags[@]}"
make -j"${proc}" V=1
make_install "${global}" "${priv_install}"
