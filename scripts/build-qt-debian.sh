#!/usr/bin/env bash
#
# Copyright (C) 2021 Savoir-faire Linux Inc.
#
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
# Commentary
#
# This script is made separate from the main build-package-debian.sh
# script, to allow for building Qt in its own, separate environment.
# There were link problems previously due to Qt pulling in FFmpeg
# libraries from the system and somehow the libjami (partly?) using it
# as part of its build.
set -e

if [[ ${DISTRIBUTION: -3} != _qt ]]; then
    echo "error: attempting to build a non-Qt distribution with $0!"
    exit 1
fi

# Strip the _qt suffix; this makes things neater to keep things per
# "real" distribution and makes the deploy script logic simpler.
DISTRIBUTION=${DISTRIBUTION:0:-3}

# Set the host architecture as armhf and add some specific architecture
# options to the package builder.
if grep -q "raspbian_10_armhf" <<< "${DISTRIBUTION}"; then
    echo "Adding armhf as the host architecture."
    export HOST_ARCH=arm-linux-gnueabihf
    DPKG_BUILD_OPTIONS="${DPKG_BUILD_OPTIONS} -a armhf"
fi

cache_packaging=$TARBALLS/$DISTRIBUTION
mkdir -p "$cache_packaging"

deb_arch=$(dpkg --print-architecture)
qt_deb_name=libqt-jami_${DEBIAN_QT_VERSION}_${deb_arch}.deb
qt_deb_path=${cache_packaging}/${qt_deb_name}

if [ -f "${qt_deb_path}" ] && [ "${FORCE_REBUILD_QT}" != "true" ]; then
    # Copy libqt-jami to output.
    cp --reflink=auto "${qt_deb_path}" /opt/output/
    echo "Qt package found in build cache: $qt_deb_path
Set FORCE_REBUILD_QT to 'true' to force rebuild it."
    exit 0
fi

(
    flock 9                 # block until the lock file is gone
    test -f "${qt_deb_path}" && exit 0 # check again

    mkdir /opt/libqt-jami-build
    cd /opt/libqt-jami-build

    qt_version=${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}
    tarball_name=qt-everywhere-src-${qt_version}.tar.xz
    cached_tarball=$TARBALLS/$tarball_name
    qt_base_url=https://download.qt.io/archive/qt/\
${QT_MAJOR}.${QT_MINOR}/${qt_version}/single

    if [ ! -d "${TARBALLS}" ] || [ ! -w "${TARBALLS}" ]; then
        echo "error: $TARBALLS does not exist or is not writable"
        exit 1
    fi

    if [ ! -f "${cached_tarball}" ]; then
        (
            flock 8         # block until the lock file is gone
            test -f "${cached_tarball}" && exit 0 # check again

            temp_dir=$(mktemp -d)
            cd "${temp_dir}"
            wget "${qt_base_url}/${tarball_name}"
            echo -n "${QT_TARBALL_CHECKSUM}  ${tarball_name}" | sha256sum -c - || \
                (echo "Qt tarball checksum mismatch; quitting" && exit 1)
            mv "${tarball_name}" "${cached_tarball}"
            rm -rf "${temp_dir}"
        ) 8>"${cached_tarball}.lock"

    fi

    cp "${cached_tarball}" "libqt-jami_${qt_version}.orig.tar.xz"
    tar xvf "libqt-jami_${qt_version}.orig.tar.xz"
    mv "qt-everywhere-src-${qt_version}" "libqt-jami-${qt_version}"
    cd "libqt-jami-${qt_version}"

    # Extract the debian folder
    tar xf "/src/$RELEASE_TARBALL_FILENAME" ring-project/packaging/rules/debian-qt \
        --strip-components=3 && mv debian-qt debian

    # Create the changelog file.
    DEBEMAIL="The Jami project <jami@gnu.org>" dch --create \
            --package libqt-jami \
            --newversion "${DEBIAN_QT_VERSION}" "New libqt-jami release"
    DEBEMAIL="The Jami project <jami@gnu.org>" dch --release \
            --distribution "unstable" debian/changelog

    # Build and package Qt.
    dpkg-buildpackage -uc -us ${DPKG_BUILD_OPTIONS}

    # Cache the built .deb.
    mv "../${qt_deb_name}" "${qt_deb_path}"

) 9>"${qt_deb_path}.lock"

# Copy libqt-jami to output.
cp --reflink=auto "${qt_deb_path}" /opt/output/
