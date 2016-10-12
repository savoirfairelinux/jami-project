#!/bin/bash

rootdir=$(pwd)
HOST=i686-w64-mingw32
ARCH=32
CMAKE_TOOLCHAIN_FILE=$rootdir/lrc/cmake/winBuild.cmake

while test -n "$1"
do
  case "$1" in
  --clean)
  ;;
  --arch=*)
  ARCH="${1#--arch=}"
  ;;
  esac
  shift
done

if [ "$ARCH" = "64" ]
then
HOST=x86_64-w64-mingw32
CMAKE_TOOLCHAIN_FILE=$rootdir/lrc/cmake/winBuild64.cmake
fi

INSTALL_PREFIX=$rootdir/daemon/_win${ARCH}


cd daemon/contrib
mkdir -p native${ARCH}
cd native${ARCH}
../bootstrap --host=${HOST}
make fetch || exit 1
make -j4 || exit 1
cd ../..
./autogen.sh || exit 1
mkdir -p "build${ARCH}"
cd build${ARCH}
$rootdir/daemon/configure --host=${HOST} --without-dbus --prefix=$INSTALL_PREFIX
rsync -a $rootdir/daemon/src/buildinfo.cpp ./src/buildinfo.cpp
make -j4 install || exit 1
cd $rootdir

cd lrc
mkdir -p build${ARCH}
cd build${ARCH}
export CMAKE_PREFIX_PATH=/usr/${HOST}/sys-root/mingw/lib/cmake
cmake -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX -DRING_BUILD_DIR=$INSTALL_PREFIX -DENABLE_LIBWRAP=true ..
make -j4 install || exit 1
cd $rootdir

cd client-windows
git submodule update --init
if [ ! -f "../daemon/_win${ARCH}/bin/WinSparkle.dll" ]
then
cd winsparkle
git submodule init && git submodule update
mkdir -p build${ARCH} && cd build${ARCH}
cmake -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX ../cmake
make -j4 || exit 1
make install
cd ../../
fi
if [ ! -f "../daemon/_win${ARCH}/bin/libqrencode.dll" ]
then
cd libqrencode
./autogen.sh || exit 1
mkdir -p build${ARCH} && cd build${ARCH}
../configure --host=${HOST} --prefix=$INSTALL_PREFIX
make -j4 || exit 1
make install
cd ../..
fi
mkdir -p build${ARCH}
cd build${ARCH}
${HOST}-qmake-qt5 ../RingWinClient.pro -r -spec win32-g++ RING=$INSTALL_PREFIX
make -j4 || exit 1
make install
