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
cp /opt/ring-project-ro/packaging/rules/rpm/* .
rm jami-libqt.spec

# Prepare the build tree.
rpmdev-setuptree

# Copy the source tarball.
cp /opt/ring-project-ro/jami_*.tar.gz /root/rpmbuild/SOURCES

QT_JAMI_PREFIX="/usr/lib64/qt-jami"
PATH="${QT_JAMI_PREFIX}/bin:${PATH}"
LD_LIBRARY_PATH="${QT_JAMI_PREFIX}/lib:${LD_LIBRARY_PATH}"
PKG_CONFIG_PATH="${QT_JAMI_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
CMAKE_PREFIX_PATH="${QT_JAMI_PREFIX}/lib/cmake:${CMAKE_PREFIX_PATH}"
QT_MAJOR=5
QT_MINOR=15
QT_PATCH=2

if [[ "${DISTRIBUTION:0:4}" == "rhel" \
   || "${DISTRIBUTION:0:13}" == "opensuse-leap" ]]; then

    RPM_PATH=/opt/cache-packaging/${DISTRIBUTION}/jami-libqt-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}-1.x86_64.rpm
    if [[ "${DISTRIBUTION:0:4}" == "rhel" ]]; then
        RPM_PATH=/opt/cache-packaging/${DISTRIBUTION}/jami-libqt-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}-1.el8.x86_64.rpm
    fi

    if [ ! -f "${RPM_PATH}" ]; then
        mkdir /opt/qt-jami-build
        cd /opt/qt-jami-build
        cp /opt/ring-project-ro/packaging/rules/rpm/jami-libqt.spec .

        QT_TARBALL_CHECKSUM="3a530d1b243b5dec00bc54937455471aaa3e56849d2593edb8ded07228202240"
        wget https://download.qt.io/archive/qt/${QT_MAJOR}.${QT_MINOR}/${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}/single/qt-everywhere-src-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.tar.xz

        if ! echo -n ${QT_TARBALL_CHECKSUM} qt-everywhere-src-*.tar.xz | sha256sum -c -
        then
            echo "qt tarball checksum mismatch; quitting"
            exit 1
        fi

        mv qt-everywhere-src-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.tar.xz /root/rpmbuild/SOURCES/jami-qtlib_${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}.tar.xz
        sed -i "s/RELEASE_VERSION/${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}/g" jami-libqt.spec
        rpmdev-bumpspec --comment="Automatic nightly release" \
                        --userstring="Jenkins <jami@lists.savoirfairelinux.net>" jami-libqt.spec

        rpmbuild -ba jami-libqt.spec
        mkdir -p /opt/cache-packaging/${DISTRIBUTION}/

        if [[ "${DISTRIBUTION:0:4}" == "rhel" ]]; then
            cp /root/rpmbuild/RPMS/x86_64/jami-libqt-${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}-1.el8.x86_64.rpm ${RPM_PATH}
        else
            cp /root/rpmbuild/RPMS/x86_64/jami-libqt-*.rpm ${RPM_PATH}
        fi
    fi
    rpm --install ${RPM_PATH}
    cp ${RPM_PATH} /opt/output
    cd /opt/ring-project
fi

# Set the version and associated comment.
sed -i "s/RELEASE_VERSION/${RELEASE_VERSION}/g" *.spec
rpmdev-bumpspec --comment="Automatic nightly release" \
                --userstring="Jenkins <jami@lists.savoirfairelinux.net>" *.spec

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

# TODO: One click install: create a package that only installs the
# Jami RPM repo, the GPG key, then proceeds install the jami-qt
# package (will should at this point pull its own dependencies such as
# jami-libclient and jami-daemon from the newly configured
# repository).  See how Cisco OpenH264, Google Chrome, rpmfusion, COPR
# do it for inspiration.

## JAMI ONE CLICK INSTALL RPM

#copy script jami-all.postinst which add repo
mkdir -p /root/rpmbuild/BUILD/ring-project/packaging/rules/one-click-install/
cp jami-all.postinst  /root/rpmbuild/BUILD/ring-project/packaging/rules/one-click-install/

# build the package
rpmbuild -ba jami-gnome.spec jami-qt.spec

# move to output
mkdir -p /opt/output/one-click-install
mv /root/rpmbuild/RPMS/*/* /opt/output/one-click-install
touch /opt/output/one-click-install/.packages-built
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output/one-click-install