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

# Qt_MIN_VER required for client-qt
QT5_MIN_VER="5.14"

global=false
appimage=''
static=''
client=''
qt5ver=''
qt5path=''
subversion=''
proc='1'
priv_install=true
while getopts gsc:q:v:Q:P:p:u:a OPT; do
  case "$OPT" in
    g)
      global='true'
    ;;
    a)
      appimage='-DENABLE_LIBWRAP=true'
      static='-DENABLE_STATIC=true'
      priv_install='false'
    ;;
    s)
      static='-DENABLE_STATIC=true'
    ;;
    c)
      client="${OPTARG}"
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
    v)
      subversion="${OPTARG}"
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

# dring
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
make -j .ffmpeg
make -j"${proc}"
cd "${DAEMON}"
./autogen.sh

#keep shared Lib on MAC OSX
if [ "$OSTYPE" != "darwin"* ] && [ ! "$appimage" ] ; then
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

    installed_qt5ver=$(echo $sys_qt5ver| cut -d'.' -f 2)
    required_qt5ver=$(echo $QT5_MIN_VER| cut -d'.' -f 2)

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
if [ "${global}" = "true" ]; then
  if [ "${prefix+set}" ]; then
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
             -DCMAKE_BUILD_TYPE=Debug \
             -DCMAKE_INSTALL_PREFIX="${prefix}" $static \
             -DQT5_VER="${qt5ver}" $appimage \
             -DQT5_PATH="${qt5path}"
  else
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
             -DCMAKE_BUILD_TYPE=Debug $static \
             -DQT5_VER="${qt5ver}" $appimage \
             -DQT5_PATH="${qt5path}"
  fi
else
  cmake ..  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
            -DRING_BUILD_DIR="${DAEMON}/src" $static \
            -DQT5_VER="${qt5ver}" $appimage \
            -DQT5_PATH="${qt5path}"
fi
make -j"${proc}"
make_install "${global}"  "${priv_install}"

# client
cd "${TOP}/${client}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
if [ "${client}" = "client-qt" ]; then
    if [ "${global}" = "true" ]; then
        if [ "${prefix+set}" ]; then
            cmake .. -DQT5_VER="${qt5ver}" \
                     -DQT5_PATH="${qt5path}" \
                     -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
                     -DCMAKE_INSTALL_PREFIX="${prefix}" $static
        else
            cmake .. -DQT5_VER="${qt5ver}" \
                     -DQT5_PATH="${qt5path}" \
                     -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" $static
        fi
    else
        cmake ..  -DQT5_VER="${qt5ver}" \
                  -DQT5_PATH="${qt5path}" \
                  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
                  -DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}" \
                  -DLRC="${INSTALL}/lrc" \
                  -DDAEMON="${INSTALL}/daemon"
    fi
else
    if [ "${global}" = "true" ]; then
        if [ "${prefix+set}" ]; then
            cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
                     -DCMAKE_INSTALL_PREFIX="${prefix}" $static
        else
            cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" $static
        fi
    else
        cmake ..  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
                  -DCMAKE_INSTALL_PREFIX="${INSTALL}/${client}" \
                  -DRINGTONE_DIR="${INSTALL}/daemon/share/ring/ringtones" \
                  -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient" $static
    fi
fi
make -j"${proc}"
make_install "${global}" "${priv_install}"

if [ "$appimage" ]; then
  cd ..
  sh ./packaging/package-appimage.sh ${subversion}
fi
