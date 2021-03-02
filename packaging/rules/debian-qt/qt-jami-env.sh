#!/usr/bin/env bash

QT_BASE_DIR=/opt/qt-jami

export QTDIR=${QT_BASE_DIR}
export PATH=${QT_BASE_DIR}/bin:${PATH}
export LD_LIBRARY_PATH=${QT_BASE_DIR}/lib/x86_64-linux-gnu:${QT_BASE_DIR}/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=${QT_BASE_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}
