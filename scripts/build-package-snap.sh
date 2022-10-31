#!/usr/bin/env bash
#
# Copyright (C) 2020-2021 Savoir-faire Linux Inc.
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


ls -la /snap/snapcraft/current/usr/bin/
tar xf "/src/$RELEASE_TARBALL_FILENAME" -C /opt
cd /opt/jami-project/packaging/rules/snap/${SNAP_PKG_NAME}/

# set the version and tarball filename
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" snapcraft.yaml

snapcraft # requires snapcraft >= 4.8

# move the built snap to output
mv *.snap /opt/output/
chown ${CURRENT_UID}:${CURRENT_GID} /opt/output/*.snap
