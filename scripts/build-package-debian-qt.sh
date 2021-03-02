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

PKG_DIR="packaging/rules/debian-qt"
if [ -z "${OVERRIDE_PACKAGING_DIR}" ]; then
    echo "OVERRIDE_PACKAGING_DIR not set."
else
    PKG_DIR="${OVERRIDE_PACKAGING_DIR}"
fi

mkdir /opt/qt-jami-build
cd /opt/qt-jami-build

wget https://download.qt.io/archive/qt/${QT_MAJOR}.${QT_MINOR}/${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}/single/qt-everywhere-src-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.tar.xz

if ! echo -n ${QT_TARBALL_CHECKSUM} qt-everywhere-src-*.tar.xz | sha256sum -c -
then
    echo "qt tarball checksum mismatch; quitting"
    exit 1
fi

mv qt-everywhere-src-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.tar.xz qt-jami_${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.orig.tar.xz
tar xvf qt-jami_${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.orig.tar.xz
mv qt-everywhere-src-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH} qt-jami-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}
cd qt-jami-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}

# import the debian folder
cp --verbose -r /opt/ring-project-ro/${PKG_DIR} debian

# create changelog file
DEBEMAIL="The Jami project <jami@gnu.org>" dch --create --package qt-jami --newversion ${DEBIAN_QT_VERSION} "New qt-jami release"
DEBEMAIL="The Jami project <jami@gnu.org>" dch --release --distribution "unstable" debian/changelog

DPKG_BUILD_OPTIONS=""
# Set the host architecture as armhf and add some specific architecture
# options to the package builder.
if grep -q "raspbian_10_qt_armhf" <<< "${DISTRIBUTION}"; then
    echo "Adding armhf as the host architecture."
    export HOST_ARCH=arm-linux-gnueabihf
    DPKG_BUILD_OPTIONS="${DPKG_BUILD_OPTIONS} -a armhf"
fi

# build and package qt
dpkg-buildpackage -uc -us ${DPKG_BUILD_OPTIONS}

# move the artifacts to output
cd ..
mv *.orig.tar* *.debian.tar* *deb *changes *dsc /opt/output
chown -R ${CURRENT_UID}:${CURRENT_GID} /opt/output/
