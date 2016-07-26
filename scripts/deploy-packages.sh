#!/bin/bash
#
# Copyright (C) 2016 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
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

#
# This script sings and deploys pacakges from packages/distro.
# It should be ran from the project root directory.
#


for i in "$@"
do
case $i in
    --distribution=*)
    DISTRIBUTION="${i#*=}"
    shift
    ;;
    --keyid=*)
    KEYID="${i#*=}"
    shift
    ;;
    --remote-location=*)
    REMOTE_LOCATION="${i#*=}"
    shift
    ;;
    *)
	echo "Unrecognized option ${i}"
	exit 1
    ;;
esac
done

##################################################
## Create local repository for the given distro ##
##################################################
echo "#########################"
echo "## Creating repository ##"
echo "#########################"

DISTRIBUTION_FOLDER=$(realpath repositories)/${DISTRIBUTION}
mkdir -p ${DISTRIBUTION_FOLDER}/conf

# Distributions file
cat << EOF > ${DISTRIBUTION_FOLDER}/conf/distributions
Origin: ring
Label: Ring ${DISTRIBUTION} Repository
Codename: ring
Architectures: i386 amd64
Components: main
Description: This repository contains Ring ${DISTRIBUTION} packages
SignWith: ${KEYID}
EOF

# Options file
cat << EOF > ${DISTRIBUTION_FOLDER}/conf/options
basedir ${DISTRIBUTION_FOLDER}
EOF

####################################
## Add packages to the repository ##
####################################

# Sign the debs
echo "##################"
echo "## signing debs ##"
echo "##################"

for package in packages/${DISTRIBUTION}{,_i386}/*.deb; do
    dpkg-sig -k ${KEYID} --sign builder ${package}
done

# Include the debs
echo "####################"
echo "## including debs ##"
echo "####################"
for package in packages/${DISTRIBUTION}{,_i386}/*.deb; do
    reprepro --verbose --basedir ${DISTRIBUTION_FOLDER} includedeb ring ${package}
done

# Rebuild the index
reprepro --verbose --basedir ${DISTRIBUTION_FOLDER} export ring

# Deploy the repository
echo "##########################"
echo "## deploying repository ##"
echo "##########################"
rsync --archive --recursive --verbose --delete ${DISTRIBUTION_FOLDER} ${REMOTE_LOCATION}

# Remove the local copy of the repository
rm -rf repositories
