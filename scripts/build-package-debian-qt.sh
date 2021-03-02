#!/usr/bin/env bash
#
# Copyright (C) 2021 Savoir-faire Linux Inc.
#
# Author: Amin Bandali <amin.bandali@savoirfairelinux.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This script is used in the packaging containers to build a snap
# package on an ubuntu base distro.


set -e

mkdir /opt/qt-jami-build
cd /opt/qt-jami-build/

wget https://download.qt.io/archive/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz

if ! echo -n "3a530d1b243b5dec00bc54937455471aaa3e56849d2593edb8ded07228202240" qt-everywhere-src-*.tar.xz | sha256sum -c -
then
    echo "qt tarball sha256sum mismatch; quitting"
    exit 1
fi

tar xvf qt-everywhere-src-5.15.2.tar.xz
cd qt-everywhere-src-5.15.2

mkdir /opt/qt-jami

mkdir build && cd build
../configure \
    -opensource \
    -confirm-license \
    -nomake examples \
    -nomake tests \
    -prefix /opt/qt-jami
make
make install

# TODO: package

# TODO: move the artifacts to output
# cd ..
# mv *.orig.tar* *.debian.tar* *deb *changes *dsc /opt/output/
# chown -R ${CURRENT_UID}:${CURRENT_GID} /opt/output/
