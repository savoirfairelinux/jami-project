#!/usr/bin/env bash
#
# Copyright (C) 2016-2019 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
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
# This script is used in the packaging containers to build packages on
# debian-based distros.
#

set -e

cp -r /opt/ring-project-ro /opt/ring-project
cd /opt/ring-project

PKG_DIR="packaging/rules/debian"
if [ -z "${OVERRIDE_PACKAGING_DIR}" ]; then
    echo "OVERRIDE_PACKAGING_DIR not set."
else
    PKG_DIR="${OVERRIDE_PACKAGING_DIR}"
fi

# import the debian folder and override files if needed
cp -r ${PKG_DIR} debian
if [ -z "${DEBIAN_PACKAGING_OVERRIDE}" ]; then
    echo "DEBIAN_PACKAGING_OVERRIDE not set."
else
    cp -r ${DEBIAN_PACKAGING_OVERRIDE}/* debian/
fi

# install build deps
apt-get clean
apt-get update
apt-get upgrade -o Acquire::Retires=10 -y
mk-build-deps --remove --install debian/control -t "apt-get -y --no-install-recommends"

# create changelog file
DEBEMAIL="The Jami project <jami@gnu.org>" dch --create --package jami --newversion ${DEBIAN_VERSION} "Automatic nightly release"
DEBEMAIL="The Jami project <jami@gnu.org>" dch --release --distribution "unstable" debian/changelog

# create orig tarball
mk-origtargz --compression gzip ${RELEASE_TARBALL_FILENAME}
rm --verbose ${RELEASE_TARBALL_FILENAME}

GET_ORIG_SOURCE_OVERRIDE_USCAN_TARBALL=$(readlink -f ../jami_*.orig.tar.gz) debian/rules get-orig-source

# move the tarball to the work directory
mkdir -p /opt/jami-packaging
mv jami_*.orig.tar.gz /opt/jami-packaging

# move to work directory
cd /opt/jami-packaging

# unpack the orig tarball
tar -xvf /opt/jami-packaging/jami_*.orig.tar.gz

# move to ring-project dir
cd ring-project

# import debian folder into ring-packaging directory
cp --verbose -r /opt/ring-project/debian .

# create the package
dpkg-buildpackage -uc -us

# move the artifacts to output
cd ..
mv *.orig.tar* *.debian.tar* *deb *changes *dsc /opt/output
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output
