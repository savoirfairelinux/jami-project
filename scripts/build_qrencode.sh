#!/usr/bin/env bash

# Flags:

# -a: architecture to build. Accepted values arm64, x86_64, unified

arch=''
while getopts "a:" OPT; do
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
  ARCHS=("arm64" "x86_64")
elif [[ "$arch" == '' ]]; then
  ARCHS=("arm64")
else
  ARCHS=("$arch")
fi

TOP="$(pwd)"
QRENCODEDIR="${TOP}/3rdparty/libqrencode"
if [ -z "$NPROC" ]; then
  NPROC=$(sysctl -n hw.ncpu || echo -n 1)
fi

for ARCH in "${ARCHS[@]}"; do
  cd "$QRENCODEDIR" || exit 1
  BUILDDIR="$ARCH-libqrencode"
  mkdir "$BUILDDIR"
  make clean
  ./autogen.sh
  ./configure --host="$ARCH" --without-png --prefix="${QRENCODEDIR}/${BUILDDIR}" CFLAGS=" -arch $ARCH $CFLAGS"
  make -j"$NPROC"
  make install
done
mkdir -p "$QRENCODEDIR"/lib
mkdir -p "$QRENCODEDIR"/include

if ((${#ARCHS[@]} == "2")); then
  echo "Making fat lib for ${ARCHS[0]} and ${ARCHS[1]}"
  LIBFILES="$QRENCODEDIR/${ARCHS[0]}-libqrencode/lib/*.a"
  for f in $LIBFILES; do
    libFile=${f##*/}
    echo "$libFile"
    lipo -create "$QRENCODEDIR/${ARCHS[0]}-libqrencode/lib/$libFile" \
      "$QRENCODEDIR/${ARCHS[1]}-libqrencode/lib/$libFile" \
      -output "${QRENCODEDIR}/lib/$libFile"
  done
else
  echo "No need for fat lib"
  rsync -ar --delete "$QRENCODEDIR/${ARCHS[0]}-libqrencode/lib/"*.a "${QRENCODEDIR}/lib/"
fi

rsync -ar --delete "$QRENCODEDIR/${ARCHS[0]}-libqrencode/include/"* "${QRENCODEDIR}/include/"
