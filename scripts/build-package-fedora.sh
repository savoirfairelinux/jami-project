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
# rpm-based distros.
#

set -e

# import the spec file
mkdir -p /opt/ring-project
cd /opt/ring-project
cp /opt/ring-project-ro/packaging/rules/fedora/ring.spec .

# Set the version
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" ring.spec
rpmdev-bumpspec --comment="Automatic nightly release" --userstring="Jenkins <ring@lists.savoirfairelinux.net>" ring.spec

# install build deps
yum-builddep -y ring.spec || echo "ignoring yum-builddep failure"

# place the source
mkdir -p /root/rpmbuild/SOURCES
cp /opt/ring-project-ro/ring_*.tar.gz /root/rpmbuild/SOURCES

# build the package
rpmbuild -ba ring.spec

# move to output
mv /root/rpmbuild/RPMS/*/* /opt/output
touch /opt/output/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output
