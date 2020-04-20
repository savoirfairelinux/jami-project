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
# rpm-based distros.
#

set -e

# import the spec file
mkdir -p /opt/ring-project
cd /opt/ring-project
cp /opt/ring-project-ro/packaging/rules/fedora/* .

#create tree for build
rpmdev-setuptree

# place the source
cp /opt/ring-project-ro/jami_*.tar.gz /root/rpmbuild/SOURCES

# Set the version
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" *.spec
if [ ${DISTRIBUTION} == "fedora_32" ]; then
    # Remove Obsoletes for Fedora 32, as we don't publish "ring"
    sed -i '/^Obsoletes:/d' *.spec
    sed -i '/^Provides:/d' *.spec
    sed -i '/^Conflicts:/d' *.spec
    # gnome-icon-theme-symbolic is removed from Fedora, but icons are well integrated
    sed -i '/gnome-icon-theme-symbolic/d' *.spec
fi

rpmdev-bumpspec --comment="Automatic nightly release" --userstring="Jenkins <ring@lists.savoirfairelinux.net>" jami.spec
rpmdev-bumpspec --comment="Automatic nightly release" --userstring="Jenkins <ring@lists.savoirfairelinux.net>" jami-one-click.spec


# install build deps
dnf builddep -y jami.spec || echo "ignoring dnf builddep failure"

# build the package
rpmbuild -ba jami.spec

# move to output
mv /root/rpmbuild/RPMS/*/* /opt/output
touch /opt/output/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output

## JAMI ONE CLICK INSTALL RPM

#copy script jami-all.postinst which add repo
mkdir -p /root/rpmbuild/BUILD/ring-project/packaging/rules/one-click-install/
cp jami-all.postinst  /root/rpmbuild/BUILD/ring-project/packaging/rules/one-click-install/

# build the package
rpmbuild -ba jami-one-click.spec

# move to output
mkdir -p /opt/output/one-click-install
mv /root/rpmbuild/RPMS/*/* /opt/output/one-click-install
touch /opt/output/one-click-install/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output/one-click-install

