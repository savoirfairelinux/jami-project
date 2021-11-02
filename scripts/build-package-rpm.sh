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
tar xf "/src/$RELEASE_TARBALL_FILENAME" ring-project/packaging/rules/rpm \
    --strip-components=3 && mv rpm/* . && rmdir rpm
rm jami-libqt.spec

# Prepare the build tree.
rpmdev-setuptree

# Copy the source tarball.
cp --reflink=auto "/src/$RELEASE_TARBALL_FILENAME" /root/rpmbuild/SOURCES

QT_JAMI_PREFIX="/usr/lib64/qt-jami"
PATH="${QT_JAMI_PREFIX}/bin:${PATH}"
LD_LIBRARY_PATH="${QT_JAMI_PREFIX}/lib:${LD_LIBRARY_PATH}"
PKG_CONFIG_PATH="${QT_JAMI_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
CMAKE_PREFIX_PATH="${QT_JAMI_PREFIX}/lib/cmake:${CMAKE_PREFIX_PATH}"
QT_MAJOR=5
QT_MINOR=15
QT_PATCH=2

QT_MAJOR_MINOR=${QT_MAJOR}.${QT_MINOR}
QT_MAJOR_MINOR_PATCH=${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}

QT_TARBALL_URL=https://download.qt.io/archive/qt/$QT_MAJOR_MINOR/\
$QT_MAJOR_MINOR_PATCH/single/qt-everywhere-src-$QT_MAJOR_MINOR_PATCH.tar.xz

QT_TARBALL_SHA256="3a530d1b243b5dec00bc54937455471aaa3e56849d2593edb8ded07228202240"
QT_TARBALL_FILE_NAME=$(basename "$QT_TARBALL_URL")
CACHED_QT_TARBALL=$TARBALLS/$QT_TARBALL_FILE_NAME

if [[ "${DISTRIBUTION}" != "opensuse-tumbleweed" ]]; then

    mkdir -p "$TARBALLS/$DISTRIBUTION"
    RPM_PATH=$TARBALLS/$DISTRIBUTION/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.x86_64.rpm
    if [[ "${DISTRIBUTION:0:4}" == "rhel" ]]; then
        RPM_PATH=$TARBALLS/${DISTRIBUTION}/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.el8.x86_64.rpm
    fi

    if [ ! -f "${RPM_PATH}" ]; then
        # The following block will only run on one build machine at a
        # time, thanks to flock.
        (
            flock 9             # block until the lock is available
            test -f "$RPM_PATH" && exit 0 # check again

            mkdir /opt/qt-jami-build
            cd /opt/qt-jami-build
            tar xf "/src/$RELEASE_TARBALL_FILENAME" \
                ring-project/packaging/rules/rpm/jami-libqt.spec \
                --strip-components=4

            # Fetch and cache the tarball, if not already available.
            if [ ! -f "$CACHED_QT_TARBALL" ]; then
                (
                    flock 8     # block until the lock file is gone
                    test -f "$CACHED_QT_TARBALL" && exit 0 # check again

                    wget "$QT_TARBALL_URL"
                    if ! echo -n ${QT_TARBALL_SHA256} "$QT_TARBALL_FILE_NAME" | sha256sum -c -
                    then
                        echo "qt tarball checksum mismatch; quitting"
                        exit 1
                    fi
                    mv "$QT_TARBALL_FILE_NAME" "$CACHED_QT_TARBALL"
                ) 8>"${CACHED_QT_TARBALL}.lock"
            fi

            cp "$CACHED_QT_TARBALL" "/root/rpmbuild/SOURCES/jami-qtlib_$QT_MAJOR_MINOR_PATCH.tar.xz"
            sed -i "s/RELEASE_VERSION/$QT_MAJOR_MINOR_PATCH/g" jami-libqt.spec
            rpmdev-bumpspec --comment="Automatic nightly release" \
                            --userstring="Jenkins <jami@lists.savoirfairelinux.net>" jami-libqt.spec

            QA_RPATHS=$(( 0x0008 )) rpmbuild -ba jami-libqt.spec
            mkdir -p "$TARBALLS/${DISTRIBUTION}"

            # Cache the built Qt RPM package.
            if [[ "${DISTRIBUTION:0:4}" == "rhel" ]]; then
                cp "/root/rpmbuild/RPMS/x86_64/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.el8.x86_64.rpm" "${RPM_PATH}"
            elif [[ "${DISTRIBUTION}" == "fedora_33" ]]; then
                cp "/root/rpmbuild/RPMS/x86_64/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.fc33.x86_64.rpm" "${RPM_PATH}"
            elif [[ "${DISTRIBUTION}" == "fedora_34" ]]; then
                cp "/root/rpmbuild/RPMS/x86_64/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.fc34.x86_64.rpm" "${RPM_PATH}"
            elif [[ "${DISTRIBUTION}" == "fedora_35" ]]; then
                cp "/root/rpmbuild/RPMS/x86_64/jami-libqt-$QT_MAJOR_MINOR_PATCH-1.fc35.x86_64.rpm" "${RPM_PATH}"
            else
                cp /root/rpmbuild/RPMS/x86_64/jami-libqt-*.rpm "${RPM_PATH}"
            fi
        ) 9>"${RPM_PATH}.lock"
    fi
    rpm --install "${RPM_PATH}"
    cp "${RPM_PATH}" /opt/output
    cd /opt/ring-project
fi

# Set the version and associated comment.
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" ./*.spec
rpmdev-bumpspec --comment="Automatic nightly release" \
                --userstring="Jenkins <jami@lists.savoirfairelinux.net>" ./*.spec

# Build the daemon and install it.
QA_RPATHS=$(( 0x0008 )) rpmbuild -ba jami-daemon.spec
rpm --install /root/rpmbuild/RPMS/x86_64/jami-daemon-*

# Build the client library and install it.
QA_RPATHS=$(( 0x0008 )) rpmbuild -ba jami-libclient.spec
rpm --install /root/rpmbuild/RPMS/x86_64/jami-libclient-*

# Build the GNOME and Qt clients.
QA_RPATHS=$(( 0x0008 )) rpmbuild -ba jami-gnome.spec jami-qt.spec

# Move the built packages to the output directory.
mv /root/rpmbuild/RPMS/*/* /opt/output
touch /opt/output/.packages-built
chown -R "$CURRENT_UID:$CURRENT_UID" /opt/output

# TODO: One click install: create a package that combines the already
# built package into one.
