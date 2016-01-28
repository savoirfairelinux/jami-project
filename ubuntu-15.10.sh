#!/usr/bin/env bash

set -e

sudo apt-get install \
    autoconf \
    automake \
    autopoint \
    cmake \
    dbus \
    g++ \
    gettext \
    gnome-icon-theme-symbolic \
    libasound2-dev \
    libavcodec-dev \
    libavcodec-extra \
    libavdevice-dev \
    libavformat-dev \
    libboost-dev \
    libclutter-gtk-1.0-dev \
    libcppunit-dev \
    libdbus-1-dev \
    libdbus-c++-dev \
    libebook1.2-dev \
    libexpat1-dev \
    libgnutls-dev \
    libgsm1-dev \
    libgtk-3-dev \
    libjack-dev \
    libnotify-dev \
    libopus-dev \
    libpcre3-dev \
    libpulse-dev \
    libsamplerate0-dev \
    libsndfile1-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libsrtp-dev \
    libswscale-dev \
    libtool \
    libudev-dev \
    libupnp-dev \
    libyaml-cpp-dev \
    openjdk-7-jdk \
    qtbase5-dev \
    sip-tester \
    swig \
    uuid-dev \
    yasm

TOP="$(pwd)"
INSTALL="${TOP}/install"

cd daemon
RING="$(pwd)"
cd contrib
mkdir -p native
cd native
../bootstrap
make -j$(nproc)
cd "${RING}"
./autogen.sh
./configure --prefix="${INSTALL}/daemon"
make -j$(nproc)
make install

cd "${TOP}/lrc"
mkdir -p build
cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX="${INSTALL}/lrc" \
  -DRING_BUILD_DIR="${RING}/src"
make
make install

cd "${TOP}/client-gnome"
mkdir -p build
cd build
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${INSTALL}/client-gnome" \
  -DLibRingClient_DIR="${INSTALL}/lrc/lib/cmake/LibRingClient"
make
sudo make install
