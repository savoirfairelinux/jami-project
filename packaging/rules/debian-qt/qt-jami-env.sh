#!/usr/bin/env bash

QT_JAMI_LIB=/usr/lib/qt-jami

export PATH="${QT_JAMI_LIB}/bin:${PATH}"
export LD_LIBRARY_PATH="${QT_JAMI_LIB}:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="${QT_JAMI_LIB}/pkgconfig:${PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="${QT_JAMI_LIB}/cmake:${CMAKE_PREFIX_PATH}"
