#!/usr/bin/env bash
#
# Copyright (C) 2016-2021 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
# Author: Amin Bandali <amin.bandali@savoirfairelinux.com>
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
# debian-based distros.
#
set -e

DPKG_BUILD_OPTIONS=""
# Set the host architecture as armhf and add some specific architecture
# options to the package builder.
if grep -q "raspbian_10_armhf" <<< "${DISTRIBUTION}"; then
    echo "Adding armhf as the host architecture."
    export HOST_ARCH=arm-linux-gnueabihf
    DPKG_BUILD_OPTIONS="${DPKG_BUILD_OPTIONS} -a armhf"
fi

cache_packaging=/opt/cache-packaging/${DISTRIBUTION}
deb_arch=$(dpkg --print-architecture)
qt_deb_name=libqt-jami_${DEBIAN_QT_VERSION}_${deb_arch}.deb
qt_deb_path=${cache_packaging}/${qt_deb_name}

if [ ! -f "${qt_deb_path}" ] || [ "${FORCE_REBUILD_QT}" = "true" ]; then
    # we need to build Qt

    cache_dir=/opt/ring-contrib
    temp_dir=$(mktemp -d)

    mkdir /opt/libqt-jami-build
    cd /opt/libqt-jami-build

    qt_version=${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}
    tarball_name=qt-everywhere-src-${qt_version}.tar.xz
    cached_tarball="${cache_dir}/${tarball_name}"
    qt_base_url=https://download.qt.io/archive/qt/${QT_MAJOR}.${QT_MINOR}/${qt_version}/single

    if [ ! -d "${cache_dir}" ] || [ ! -w "${cache_dir}" ]; then
        echo "error: $cache_dir does not exist or is not writable"
        exit 1
    fi

    if [ ! -f "${cached_tarball}" ]; then
        (
            cd "${temp_dir}"
            wget "${qt_base_url}/${tarball_name}"
            echo -n "${QT_TARBALL_CHECKSUM}  ${tarball_name}" | sha256sum -c - || \
                (echo "Qt tarball checksum mismatch; quitting" && exit 1)
            flock "${cached_tarball}.lock" mv "${tarball_name}" "${cached_tarball}"
        )
        rm -rf "${temp_dir}"
    fi

    cp "${cached_tarball}" libqt-jami_${qt_version}.orig.tar.xz
    tar xvf libqt-jami_${qt_version}.orig.tar.xz
    mv qt-everywhere-src-${qt_version} libqt-jami-${qt_version}
    cd libqt-jami-${qt_version}

    # Extract the debian folder
    tar xf "/src/$RELEASE_TARBALL_FILENAME" ring-project/packaging/rules/debian-qt \
        --strip-components=3 && mv debian-qt debian

    # create changelog file
    DEBEMAIL="The Jami project <jami@gnu.org>" dch --create \
            --package libqt-jami \
            --newversion ${DEBIAN_QT_VERSION} "New libqt-jami release"
    DEBEMAIL="The Jami project <jami@gnu.org>" dch --release \
            --distribution "unstable" debian/changelog

    # build and package qt
    dpkg-buildpackage -uc -us ${DPKG_BUILD_OPTIONS}

    # copy the built deb to cache
    mkdir -p ${cache_packaging}/
    cp ../${qt_deb_name} ${qt_deb_path}
fi

# install libqt-jami from cache
apt-get install -y ${qt_deb_path}

# copy libqt-jami to output
cp ${qt_deb_path} /opt/output/

# Set up work directory.
mkdir -p /jami/work && cd /jami/work

# Create a changelog file, required by dpkg-buildpackage.
mkdir debian
DEBEMAIL="The Jami project <jami@gnu.org>" dch --create --package jami \
        --newversion ${DEBIAN_VERSION} "Automatic nightly release"
DEBEMAIL="The Jami project <jami@gnu.org>" dch --release \
        --distribution "unstable" debian/changelog

# Unpack the source tarball.
tar -xvf /src/"$RELEASE_TARBALL_FILENAME" --strip-components=1

# Expose the debian directory from here, augmented with the changelog.
cp debian/changelog packaging/rules/debian
rm -r debian
ln -s packaging/rules/debian .

# Create the binary packages.
dpkg-buildpackage -b -uc -us ${DPKG_BUILD_OPTIONS}

# Move the artifacts to the output.
mv ../*deb /opt/output        # .deb and .ddeb packages
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output
