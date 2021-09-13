#!/usr/bin/env bash
#
# Copyright (C) 2021 Savoir-faire Linux Inc.
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
# This script is used in the packaging containers to build packages on
# debian-based distros.

set -e

DPKG_BUILD_OPTIONS=""
# Set the host architecture as armhf and add some specific architecture
# options to the package builder.
if grep -q "raspbian_10_armhf" <<< "${DISTRIBUTION}"; then
    echo "Adding armhf as the host architecture."
    export HOST_ARCH=arm-linux-gnueabihf
    DPKG_BUILD_OPTIONS="${DPKG_BUILD_OPTIONS} -a armhf"
fi

install_deps()
{
    apt-get update
    mk-build-deps \
        --remove --install \
        --tool "apt-get -y --no-install-recommends -o Acquire::Retries=10" \
        "debian/control"
}

install_dummy()
{
    cat <<EOF > dummy-libqt-jami.equivs
Package: libqt-jami
Version: 1.0
Maintainer: The Jami project <jami@gnu.org>
Architecture: all
Description: Dummy libqt-jami package
EOF
    equivs-build dummy-libqt-jami.equivs
    dpkg -i libqt-jami_1.0_all.deb
}

remove_dummy()
{
    dpkg -r libqt-jami
}

case "$1" in
    qt-deps)
        (
            cd /tmp/builddeps
            install_deps
            dpkg -r libqt-jami-build-deps
        )
        rm -rf /tmp/builddeps
        exit 0
        ;;
    jami-deps)
        (
            cd /tmp/builddeps
            install_dummy
            install_deps
            dpkg -r jami-build-deps
            remove_dummy
        )
        rm -rf /tmp/builddeps
        exit 0
        ;;
    *)
        printf "Usage: %s {qt-deps|jami-deps}\n" "$0"
        exit 1
        ;;
esac
