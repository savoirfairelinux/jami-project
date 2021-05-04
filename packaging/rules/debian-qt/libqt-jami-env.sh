#!/usr/bin/env bash

QT_JAMI_PREFIX=/usr/lib/libqt-jami

export PATH="${QT_JAMI_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${QT_JAMI_PREFIX}/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="${QT_JAMI_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="${QT_JAMI_PREFIX}/lib/cmake:${CMAKE_PREFIX_PATH}"
