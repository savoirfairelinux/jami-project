#!/usr/bin/env bash

# Flags:

  # -a: architecture to build. Accepted values arm64, x86_64, unified

arch=''
while getopts a OPT; do
  case "$OPT" in
    a)
      arch="${OPTARG}"
    ;;
    \?)
      exit 1
    ;;
  esac
done

if [[ "$arch" == 'unified' ]]; then
    ARCHS=("arm64", "x86_64")
elif [[ "$arch" == '' ]]; then
    ARCHS=("arm64")
else
    ARCHS=("$arch")
fi

TOP="$(pwd)"
INSTALL="${TOP}/install"

DAEMON=${TOP}/daemon
cd "$DAEMON"

FAT_CONTRIB_DIR=$DAEMON/contrib/apple-darwin
mkdir -p $FAT_CONTRIB_DIR
SDKROOT=`xcode-select -print-path`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
for ARCH in "${ARCHS[@]}"
do
  HOST="$ARCH-apple-darwin"
  mkdir -p contrib/native-$ARCH
  (
      cd contrib/native-$ARCH
      if [ "$ARCH" = "arm64" ]
      then
          ../bootstrap --host="$HOST"
      else
         ../bootstrap
      fi

      echo "Building contrib"
      make -j$NPROC || exit 1
  )
done

mkdir -p $FAT_CONTRIB_DIR/lib
if ((${#ARCHS[@]} == "2"))
then
  echo "Making fat lib for ${ARCHS[0]} and ${ARCHS[1]}"
  LIBFILES="$DAEMON/contrib/${ARCHS[0]}-apple-darwin/lib/"*.a
  for f in $LIBFILES
  do
    libFile=${f##*/}
    echo "Processing $libFile lib..."
    #There is only 2 ARCH max... So let's make it simple
    lipo -create  "$DAEMON/contrib/${ARCHS[0]}-apple-darwin/lib/$libFile"  \
                  "$DAEMON/contrib/${ARCHS[1]}-apple-darwin/lib/$libFile" \
                  -output "$FAT_CONTRIB_DIR/lib/$libFile"
  done
else
  echo "No need for fat lib"
  rsync -ar --delete "$DAEMON/contrib/${ARCHS[0]}-apple-darwin/lib/"*.a $FAT_CONTRIB_DIR/lib
fi

rsync -ar --delete $DAEMON/contrib/${ARCHS[0]}-apple-darwin/include* $FAT_CONTRIB_DIR/
for ARCH in "${ARCHS[@]}"
do
  cd $DAEMON
  HOST="$ARCH-apple-darwin"
  echo "Building daemon"
  echo `pwd`
  CONFIGURE_FLAGS=" --without-dbus --host=${HOST} --without-natpmp -with-contrib=$DAEMON/contrib/$HOST --prefix=${INSTALL}/daemon/$ARCH"

  BUILD_TYPE="Release"
  if [ "${debug}" = "true" ]; then
     BUILD_TYPE="Debug"
     CONFIGURE_FLAGS+=" --enable-debug"
  fi

   echo "***************"
   echo $CONFIGURE_FLAGS
  ./autogen.sh || exit

    # We need to copy this file or else it's just an empty file
  rsync -a $DAEMON/src/buildinfo.cpp ./src/buildinfo.cpp
  mkdir -p "build-macos-$ARCH"
  cd "build-macos-$ARCH"

  $DAEMON/configure $CONFIGURE_FLAGS ARCH="$ARCH" SDKROOT="$SDKROOT"|| exit 1

  echo $CONFIGURE_FLAGS

  rsync -a $DAEMON/src/buildinfo.cpp ./src/buildinfo.cpp

  make -j$NPROC || exit 1
  make install || exit 1
  cd $DAEMON
done

FAT_INSTALL_DIR="${INSTALL}/daemon/"
FAT_INSTALL_DIR_LIB="${FAT_INSTALL_DIR}/lib/"
mkdir -p $FAT_INSTALL_DIR1

if ((${#ARCHS[@]} == "2"))
then
  #daemon
  lipo -create  "${INSTALL}/daemon/${ARCHS[0]}/lib/libjami.a"  \
                "${INSTALL}/daemon/${ARCHS[1]}/lib/libjami.a"  \
                  -output "$FAT_INSTALL_DIR_LIB/libjami.a"
else
  echo "No need for fat lib"
  rsync -ar --delete ${INSTALL}/daemon/${ARCHS[0]}/lib/libjami.a ${FAT_INSTALL_DIR_LIB}
fi

rsync -ar --delete ${INSTALL}/daemon/${ARCHS[0]}/include/* $FAT_INSTALL_DIR/include
