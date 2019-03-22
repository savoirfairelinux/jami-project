#!/usr/bin/env bash
#
# Copyright (C) 2016-2019 Savoir-faire Linux Inc.
#
# Author: Stefan Langenmaier <stefan.langenmaier@savoirfairelinux.com>
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

layman -f -a ring-overlay

cp /opt/ring-project-ro/${RELEASE_TARBALL_FILENAME} /usr/portage/distfiles

cd /var/lib/layman/ring-overlay && bash scripts/bump-ring-ebuilds.sh /usr/portage/distfiles/${RELEASE_TARBALL_FILENAME}

# problem with cirrcular deps
USE="-qt5" emerge -1 dev-util/cmake

emerge jami-gnome kde-ring

touch /opt/output/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output
