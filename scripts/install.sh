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
  # -w: do not use Qt WebEngine

set -ex

# Qt_MIN_VER required for client-qt
QT_MIN_VER="6.2"

debug=
global=false
static=''
client=''
qtpath=''
proc='1'
priv_install=true
enable_libwrap=true
enable_webengine=true

while getopts gsc:dQ:P:p:uWw OPT; do
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
    Q)
      qtpath="${OPTARG}"
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
    w)
      enable_webengine='false'
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

if [[ "${enable_libwrap}" != "true" ]]; then
  # Disable shared if requested
  if [[ "$OSTYPE" != "darwin"* ]]; then
    CONFIGURE_FLAGS+=" --disable-shared"
  fi
fi

BUILD_TYPE="Release"
if [ "${debug}" = "true" ]; then
  BUILD_TYPE="Debug"
  CONFIGURE_FLAGS+=" --enable-debug"
fi

# Build the daemon itself.
test -f configure || ./autogen.sh

if [ "${global}" = "true" ]; then
    ./configure ${CONFIGURE_FLAGS} ${prefix:+"--prefix=$prefix"}
else
    ./configure ${CONFIGURE_FLAGS} --prefix="${INSTALL}/daemon"
fi
make -j"${proc}" V=1
make_install "${global}" "${priv_install}"

# For the client-qt, verify system's version if no path provided
if [ "${client}" = "client-qt" ] && [ -z "$qtpath" ]; then
    sys_qtver=""
    if command -v qmake &> /dev/null; then
        sys_qtver=$(qmake -v)
    elif command -v qmake-qt6 &> /dev/null; then
        sys_qtver=$(qmake-qt6 -v)   # Fedora
    elif command -v qmake6 &> /dev/null; then
        sys_qtver=$(qmake6 -v) # macOS
    else
        echo "No valid Qt found"; exit 1;
    fi

    sys_qtver=${sys_qtver#*Qt version}
    sys_qtver=${sys_qtver%\ in\ *}

    installed_qtver=$(echo "$sys_qtver" | cut -d'.' -f 2)
    required_qtver=$(echo $QT_MIN_VER | cut -d'.' -f 2)

    if [[ $installed_qtver -ge $required_qtver ]] ; then
        # Set qtpath to empty in order to use system's Qt.
        qtpath=""
    else
        echo "No valid Qt found"; exit 1;
    fi
fi

# libringclient
cd "${TOP}/lrc"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
# Compute LRC CMake flags
lrc_cmake_flags=(-DCMAKE_PREFIX_PATH="${qtpath}"
                 -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
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
                    -DCMAKE_PREFIX_PATH="${qtpath}")

if [ "${client}" = "client-qt" ]; then
    if [ "${global}" = "true" ]; then
        client_cmake_flags+=(${prefix:+"-DCMAKE_INSTALL_PREFIX=$prefix"}
                             -DWITH_WEBENGINE="${enable_webengine}"
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
