#!/usr/bin/env bash

# Build and install to a local prefix under this repository.
export OSTYPE

# Flags:

  # -g: install globally instead for all users
  # -s: link everything statically, no D-Bus communication. More likely to work!
  # -p: number of processors to use
  # -u: disable use of privileges (sudo) during install
  # -W: disable libwrap and shared library
  # -w: do not use Qt WebEngine
  # -a: arch to build

set -ex

# Qt_MIN_VER required for client-qt
QT_MIN_VER="6.2"

debug=
global=false
static=''
qtpath=''
proc='1'
priv_install=true
enable_libwrap=true
enable_webengine=true
arch=''

while getopts gsc:dQ:P:p:uWw:a: OPT; do
  case "$OPT" in
    g)
      global='true'
    ;;
    s)
      static='-DENABLE_STATIC=true'
    ;;
    d)
      debug=true
    ;;
    Q)
      qtpath="${OPTARG}"
    ;;
    a)
      arch="${OPTARG}"
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

if [[ "$OSTYPE" == "darwin"* ]]; then
    sh ${TOP}/scripts/mac_dependencies_build.sh -a "$arch"
else
    cd "$DAEMON"

    # Build the contribs.
    mkdir -p contrib/native
    (
        cd contrib/native
        ../bootstrap ${prefix:+"--prefix=$prefix"}
        make -j"${proc}"
    )

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
        if command -v qmake6 &> /dev/null; then
            sys_qtver=$(qmake6 -v)
        elif command -v qmake-qt6 &> /dev/null; then
            sys_qtver=$(qmake-qt6 -v) # Fedora
        elif command -v qmake &> /dev/null; then
            sys_qtver=$(qmake -v)
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
fi

# client
cd "${TOP}/client-qt"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

client_cmake_flags=(-DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
                    -DCMAKE_PREFIX_PATH="${qtpath}"
                    -DENABLE_LIBWRAP="${enable_libwrap}"
                    -DWITH_WEBENGINE="${enable_webengine}")

if [[ "$OSTYPE" == "darwin"* ]]; then
  #detect arch for macos
  CMAKE_OSX_ARCHITECTURES="arm64"
  if [[ "$arch" == 'unified' ]]; then
      CMAKE_OSX_ARCHITECTURES="x86_64;arm64"
  elif [[ "$arch" != '' ]]; then
      CMAKE_OSX_ARCHITECTURES="$arch"
  fi
  client_cmake_flags+=(-DCMAKE_OSX_ARCHITECTURES="${CMAKE_OSX_ARCHITECTURES}")
  # build qrencode
  client=${TOP}/client-qt
  (
    cd ${client}
    ./extras/scripts/build_qrencode.sh -a "$arch"
  )
fi

if [ "${global}" = "true" ]; then
    client_cmake_flags+=(${prefix:+"-DCMAKE_INSTALL_PREFIX=$prefix"}
                         $static)
else
    client_cmake_flags+=(-DCMAKE_INSTALL_PREFIX="${INSTALL}"
                         -DLIBJAMI_BUILD_DIR="${DAEMON}/src")
fi

echo "info: Configuring $client client with flags: ${client_cmake_flags[*]}"
cmake .. "${client_cmake_flags[@]}"
make -j"${proc}" V=1
make_install "${global}" "${priv_install}"
