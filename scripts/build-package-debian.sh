#!/usr/bin/env bash
#
# This script is used in the packaging containers to build packages on
# debian-based distros.
#

set -e

cp -r /opt/ring-project-ro /opt/ring-project
cd /opt/ring-project

# install build deps
apt-get update
apt-get upgrade -y
mk-build-deps --remove --install debian/control -t "apt-get -y --no-install-recommends"

# create changelog file
dch --create --package ring --newversion ${DEBIAN_VERSION} "Automatic nightly release"
dch --release --distribution "unstable" debian/changelog

# create orig tarball
mk-origtargz ${RELEASE_TARBALL_FILENAME}
rm --verbose ${RELEASE_TARBALL_FILENAME}
GET_ORIG_SOURCE_OVERRIDE_USCAN_TARBALL=$(realpath ../ring_*.orig.tar.gz) debian/rules get-orig-source

# move the tarball to the work directory
mkdir -p /opt/ring-packaging
mv ring_*.orig.tar.gz /opt/ring-packaging

# move to work directory
cd /opt/ring-packaging

# unpack the orig tarball
tar -xvf /opt/ring-packaging/ring_*.orig.tar.gz

# move to ring-project dir
cd ring-project

# import debian folder
cp --verbose -r /opt/ring-project/debian .

# create the package
dpkg-buildpackage -uc -us

# move the artifacts to output
cd ..
mv *.orig.tar* *.debian.tar* *deb *changes *dsc /opt/output
chown -R ${CURRENT_UID}:${CURRENT_UID} /opt/output
