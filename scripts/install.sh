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
qt5ver=''
qt5path=''
proc='1'
priv_install=true
while getopts gsc:q:Q:P:p:u OPT; do
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

# libringclient
cd "${TOP}/lrc"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
if [ "${global}" = "true" ]; then
  if [ "${prefix+set}" ]; then
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
             -DCMAKE_BUILD_TYPE=Debug \
             -DCMAKE_INSTALL_PREFIX="${prefix}" $static \
             -DQT_MIN_VER="${qt5ver}" \
             -DQT5_PATH="${qt5path}"
  else
    cmake .. -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
             -DCMAKE_BUILD_TYPE=Debug $static \
             -DQT_MIN_VER="${qt5ver}" \
             -DQT5_PATH="${qt5path}"
  fi
else
  cmake ..  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
            -DRING_BUILD_DIR="${DAEMON}/src" $static \
            -DQT_MIN_VER="${qt5ver}" \
            -DQT5_PATH="${qt5path}"
fi
make -j"${proc}"
make_install "${global}"  "${priv_install}"

# client
cd "${TOP}/${client}"
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"
if [ "${client}" = "client-qt" ]; then
    echo building client-qt using Qt ${qt5ver}
    if ! command -v qmake &> /dev/null; then
      eval ${qt5path}/bin/qmake PREFIX="${INSTALL}/${client}" ..
    else
      # Extract installed Qt version and compare with minimum required
      sys_qt5ver=$(qmake -v)
      sys_qt5ver=${sys_qt5ver#*Qt version}
      sys_qt5ver=${sys_qt5ver%\ in\ *}

      installed_qt5ver=$(echo $sys_qt5ver| cut -d'.' -f 2)
      required_qt5ver=$(echo $qt5ver| cut -d'.' -f 2)

      if [[ $installed_qt5ver -ge $required_qt5ver ]] ; then
        qmake PREFIX="${INSTALL}/${client}" ..
      else
        eval ${qt5path}/bin/qmake PREFIX="${INSTALL}/${client}" ..
      fi
   fi
else
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
fi
make -j"${proc}"
make_install "${global}" "${priv_install}"

# copy runtime files
python ../copy-runtime-files.py -q ${qt5path}
