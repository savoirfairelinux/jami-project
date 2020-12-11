#!/usr/bin/env bash
#
# Copyright (C) 2020 Savoir-faire Linux Inc.
#
# Author: Sébastien Blin <sebastien.blin@savoirfairelinux.com>
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

cp -r /opt/ring-project-ro /opt/ring-project
cd /opt/ring-project

subversion=""
if [ ! -z "$1" ]; then
    subversion="--subversion $1"
fi

git submodule update --init
git fetch --recurse-submodules=yes -p
./make-ring.py --dependencies --qt
./make-ring.py --install --qt --appimage ${subversion}
mv client-qt/*.AppImage /opt/output/
chown ${CURRENT_UID}:${CURRENT_GID} /opt/output/*.AppImage