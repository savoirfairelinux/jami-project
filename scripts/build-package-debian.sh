#!/usr/bin/env bash
#
# Copyright (C) 2016 Savoir-faire Linux Inc.
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

# import the debian folder and override files if needed
cp -r packaging/rules/debian .
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
dch --create --package ring --newversion ${DEBIAN_VERSION} "Automatic nightly release"
dch --release --distribution "unstable" debian/changelog

# create orig tarball
# mk-origtargz isn't in ubuntu_14.04
if [ "${DISTRIBUTION}" = "ubuntu_14.04" ] || [ "${DISTRIBUTION}" = "ubuntu_14.04_i386" ]; then
    mv ${RELEASE_TARBALL_FILENAME} ../ring_${DEBIAN_VERSION}.orig.tar.gz
else
    mk-origtargz ${RELEASE_TARBALL_FILENAME}
    rm --verbose ${RELEASE_TARBALL_FILENAME}
fi

GET_ORIG_SOURCE_OVERRIDE_USCAN_TARBALL=$(readlink -f ../ring_*.orig.tar.gz) debian/rules get-orig-source

# move the tarball to the work directory
mkdir -p /opt/ring-packaging
mv ring_*.orig.tar.gz /opt/ring-packaging

# move to work directory
cd /opt/ring-packaging

# unpack the orig tarball
tar -xvf /opt/ring-packaging/ring_*.orig.tar.gz

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
