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

# Exit immediately if a command exits with a non-zero status
set -e

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
    --remote-repository-location=*)
    REMOTE_REPOSITORY_LOCATION="${i#*=}"
    shift
    ;;
    --remote-manual-download-location=*)
    REMOTE_MANUAL_DOWNLOAD_LOCATION="${i#*=}"
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

DISTRIBUTION_REPOSITOIRY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
rm -rf ${DISTRIBUTION_REPOSITOIRY_FOLDER}
mkdir -p ${DISTRIBUTION_REPOSITOIRY_FOLDER}

# .repo file
cat << EOF > ${DISTRIBUTION_REPOSITOIRY_FOLDER}/ring-nightly-man.repo
[ring]
name=Ring \$releasever - \$basearch - ring
baseurl=https://dl.ring.cx/ring-nightly/fedora_\$releasever
gpgcheck=1
gpgkey=https://dl.ring.cx/ring.pub.key
enabled=1
EOF

####################################
## Add packages to the repository ##
####################################

# Sign the rpms
echo "##################"
echo "## signing rpms ##"
echo "##################"

# RPM macros
if [ ! -f ~/.rpmmacros ];
then
    echo "%_signature gpg" > ~/.rpmmacros
    echo "%_gpg_name ${KEYID}" >> ~/.rpmmacros
fi

for package in packages/${DISTRIBUTION}*/*.rpm; do
    rpmsign --resign --key-id=${KEYID} ${package}
    cp ${package} ${DISTRIBUTION_REPOSITOIRY_FOLDER}
done

# Create the repo
createrepo --update ${DISTRIBUTION_REPOSITOIRY_FOLDER}

#######################################
## create the manual download folder ##
#######################################
DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER=$(realpath manual-download)/${DISTRIBUTION}
mkdir -p ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
for package in packages/${DISTRIBUTION}*/*.rpm; do
    cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
    package_name=$(rpm -qp --queryformat '%{NAME}' ${package})
    package_arch=$(rpm -qp --queryformat '%{ARCH}' ${package})
    cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_name}_${package_arch}.rpm
done

############
## deploy ##
############

# Deploy the repository
echo "##########################"
echo "## deploying repository ##"
echo "##########################"
rsync --archive --recursive --verbose --delete ${DISTRIBUTION_REPOSITOIRY_FOLDER} ${REMOTE_REPOSITORY_LOCATION}

# deploy the manual download files
echo "#####################################"
echo "## deploying manual download files ##"
echo "#####################################"
rsync --archive --recursive --verbose --delete ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER} ${REMOTE_MANUAL_DOWNLOAD_LOCATION}

# remove deployed files
rm -rf manual-download
rm -rf repositories
