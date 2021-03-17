#!/usr/bin/env bash
#
# Copyright (C) 2016-2021 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
# Author: Maxim Cournoyer <maxim.cournoyer@savoirfairelinux.com>
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

# Import the spec file.
mkdir -p /opt/ring-project
cd /opt/ring-project
cp /opt/ring-project-ro/packaging/rules/fedora/* .

# Prepare the build tree.
rpmdev-setuptree

# Copy the source tarball.
cp /opt/ring-project-ro/jami_*.tar.gz /root/rpmbuild/SOURCES

# Set the version and associated comment.
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" *.spec
rpmdev-bumpspec --comment="Automatic nightly release" \
                --userstring="Jenkins <jami@lists.savoirfairelinux.net>" *.spec

# TODO: We could use mock to build Fedora/RHEL packages in minimal
# chroots matching the environment defined in the spec files.  It also
# has a --chain option to chain the build of dependent packages.

# Build the daemon and install it.
rpmbuild -ba jami-daemon.spec
rpm --install /root/rpmbuild/RPMS/x86_64/jami-daemon-*

# Build the client library and install it.
rpmbuild -ba jami-libclient.spec
rpm --install /root/rpmbuild/RPMS/x86_64/jami-libclient-*

# Build the GNOME and Qt clients.
rpmbuild -ba jami-gnome.spec jami-qt.spec

# Move the built packages to the output directory.
mv /root/rpmbuild/RPMS/*/* /opt/output
touch /opt/output/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output

# TODO: One click install: create a package that combines the already
# built package into one.
