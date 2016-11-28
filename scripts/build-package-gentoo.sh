#!/usr/bin/env bash
#
# Copyright (C) 2016 Savoir-faire Linux Inc.
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

# assuming there is only one tar.gz
# otherwise the wrong one might be bumped
cp /opt/ring-project-ro/ring_* /usr/portage/distfiles

cd /var/lib/layman/ring-overlay && bash scripts/bump-ring-ebuilds.sh /usr/portage/distfiles/ring_*

emerge gnome-ring
