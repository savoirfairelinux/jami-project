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

tar xvf qt-everywhere-src-*.tar.xz
rm qt-everywhere-src-*.tar.xz
cd qt-everywhere-src-*

# import the debian folder
cp --verbose -r /opt/ring-project-ro/${PKG_DIR} debian

DPKG_BUILD_OPTIONS=""
MKBUILD_OPTIONS=""
# Set the host architecture as armhf and add some specific architecture
# options to the package builder.
if grep -q "raspbian_10_qt_armhf" <<< "${DISTRIBUTION}"; then
    echo "Adding armhf as the host architecture."
    export HOST_ARCH=arm-linux-gnueabihf
    dpkg --add-architecture armhf
    DPKG_BUILD_OPTIONS="${DPKG_BUILD_OPTIONS} -a armhf"
    MKBUILD_OPTIONS="${MKBUILD_OPTIONS} --host-arch armhf"
fi

# install build deps
apt-get clean
apt-get update
apt-get upgrade -o Acquire::Retries=10 -y
mk-build-deps ${MKBUILD_OPTIONS} --remove --install debian/control -t "apt-get -y --no-install-recommends"

# create changelog file
DEBEMAIL="The Jami project <jami@gnu.org>" dch --create --package qt-jami --newversion ${DEBIAN_VERSION} "New qt-jami release"
DEBEMAIL="The Jami project <jami@gnu.org>" dch --release --distribution "unstable" debian/changelog

# build and package qt
dpkg-buildpackage -uc -us

# move the artifacts to output
cd ..
ls -la
mv *deb *changes *dsc /opt/output/
chown -R ${CURRENT_UID}:${CURRENT_GID} /opt/output/
