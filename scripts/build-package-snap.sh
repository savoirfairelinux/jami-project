#!/usr/bin/env bash
#
# Copyright (C) 2020-2022 Savoir-faire Linux Inc.
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

tar xf "/src/$RELEASE_TARBALL_FILENAME" -C /opt

if [ -z "${SNAP_BUILD_LOCAL}" ]; then
    git config --global user.name 'The Jami project'
    git config --global user.email 'jami@gnu.org'
    mkdir -p ~/.local/share/snapcraft/provider/
    cp -rp /creds/launchpad ~/.local/share/snapcraft/provider/

    cd /opt/jami-project

    # remove these broken symlinks (otherwise snapcraft remote-build
    # will fail trying to resolve them)
    (cd docs/source/dev; rm -f daemon lrc gnome-client)

    cp -rp packaging/rules/snap/common snap
    cp -p packaging/rules/snap/${SNAP_PKG_NAME}/snapcraft.yaml snap/
    sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" snap/snapcraft.yaml
    sed -i "s|../common|snap|g" snap/snapcraft.yaml

    snapcraft remote-build \
        --launchpad-accept-public-upload \
        --build-on=${SNAP_BUILD_ARCHES// /,}

    for arch in ${SNAP_BUILD_ARCHES}; do
        if [ ! -f "${SNAP_PKG_NAME}_${RELEASE_VERSION}_${arch}.snap" ]; then
            if [ -f "${SNAP_PKG_NAME}_${arch}.txt" ]; then
                cat "${SNAP_PKG_NAME}_${arch}.txt"
            fi
        fi
    done
else
    cd /opt/jami-project/packaging/rules/snap/${SNAP_PKG_NAME}/
    sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" snapcraft.yaml
    snapcraft # requires snapcraft >= 4.8
fi

# move the built snap(s) to output
mv *.snap /opt/output/
chown ${CURRENT_UID}:${CURRENT_GID} /opt/output/*.snap
