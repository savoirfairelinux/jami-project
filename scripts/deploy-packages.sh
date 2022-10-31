#!/usr/bin/env bash
#
# Copyright (C) 2016-2021 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
# Author: Guillaume Roguez <guillaume.roguez@savoirfairelinux.com>
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
# This script syncs and deploys packages from packages/distro.
# It should be run from the project root directory.
#
# Requirements
# - createrepo-c
# - dpkg
# - reprepro
# - rpm
# - rsync
# - snapcraft

# Exit immediately if a command exits with a non-zero status
set -e

###############################
## Debian / Ubuntu packaging ##
###############################

function package_deb()
{
    DISTRIBUTION_REPOSITORY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
    mkdir -p ${DISTRIBUTION_REPOSITORY_FOLDER}

    ##################################################
    ## Create local repository for the given distro ##
    ##################################################
    echo "#########################"
    echo "## Creating repository ##"
    echo "#########################"

    mkdir ${DISTRIBUTION_REPOSITORY_FOLDER}/conf

    # Distributions file
    cat << EOF > ${DISTRIBUTION_REPOSITORY_FOLDER}/conf/distributions
Origin: jami
Label: Jami ${DISTRIBUTION} Repository
Codename: jami
Architectures: i386 amd64 armhf arm64
Components: main
Description: This repository contains Jami ${DISTRIBUTION} packages
SignWith: ${KEYID}

# TODO: Remove when April 2024 comes.
Origin: ring
Label: Ring ${DISTRIBUTION} Repository
Codename: ring
Architectures: i386 amd64 armhf arm64
Components: main
Description: This repository contains Ring ${DISTRIBUTION} packages
SignWith: ${KEYID}
EOF

    ####################################
    ## Add packages to the repository ##
    ####################################
    # Note: reprepro currently only accepts .deb files as input, but
    # Ubuntu generates their debug symbol packages as .ddeb (see:
    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=730572).  As
    # these are just regular Debian packages, simply append the .deb
    # extension to their file name to work around this.
    find ./packages -type f -name '*.ddeb' -print0 | xargs -0 -I{} mv {} {}.deb

    for package in packages/${DISTRIBUTION}*/*.deb; do
        echo "## signing: ${package} ##"
        dpkg-sig -k ${KEYID} --sign builder ${package}

        echo "## including ${package} ##"
        package_name=$(dpkg -I ${package} | grep -m 1 Package: | awk '{print $2}')
        package_arch=$(dpkg -I ${package} | grep -m 1 Architecture: | awk '{print $2}')

        if [ ${package_arch} = "all" ]; then
            # Removing to avoid the error of adding the same deb twice.
            # This happens with arch all packages, which are generated in amd64 and i386.
            reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} remove jami ${package_name}
            # TODO: Remove when April 2024 comes.
            reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} remove ring ${package_name}
        fi
        reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} includedeb jami ${package}
        # TODO: Remove when April 2024 comes.
        reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} includedeb ring ${package}
    done

    # Rebuild the index
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} export jami
    # TODO: Remove when April 2024 comes.
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} export ring

    # Show the contents
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} list jami
    # TODO: Remove when April 2024 comes.
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITORY_FOLDER} list ring

    #######################################
    ## create the manual download folder ##
    #######################################
    NAME_PATTERN=jami-all_????????.*\~dfsg*.deb
    if ls packages/${DISTRIBUTION}/${NAME_PATTERN} &> /dev/null; then
        DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER=$(realpath manual-download)/${DISTRIBUTION}
        mkdir -p ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
        cp packages/${DISTRIBUTION}/${NAME_PATTERN} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
        for package in ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${NAME_PATTERN} ; do
            package_name=$(dpkg -I ${package} | grep -m 1 Package: | awk '{print $2}')
            package_arch=$(dpkg -I ${package} | grep -m 1 Architecture: | awk '{print $2}')
            package_shortname=${package_name}_${package_arch}.deb
            rm -f ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_shortname}
            cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_shortname}
        done
    fi
}


######################
## Fedora packaging ##
######################

function package_rpm()
{
    ##################################################
    ## Create local repository for the given distro ##
    ##################################################
    echo "#########################"
    echo "## Creating repository ##"
    echo "#########################"

    local name
    local baseurl

    DISTRIBUTION_REPOSITORY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
    mkdir -p ${DISTRIBUTION_REPOSITORY_FOLDER}

    # .repo file
    name="${DISTRIBUTION%_*} \$releasever - \$basearch - jami"
    baseurl="https://dl.jami.net/${CHANNEL}/${DISTRIBUTION%_*}_\$releasever"

    cat << EOF > ${DISTRIBUTION_REPOSITORY_FOLDER}/jami-${CHANNEL}.repo
[jami]
name=$name
baseurl=$baseurl
gpgcheck=1
gpgkey=https://dl.jami.net/jami.pub.key
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
        cp ${package} ${DISTRIBUTION_REPOSITORY_FOLDER}
    done

    # Create the repo
    createrepo_c --update ${DISTRIBUTION_REPOSITORY_FOLDER}

    #######################################
    ## create the manual download folder ##
    #######################################
    local packages

    DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER=$(realpath manual-download)/${DISTRIBUTION}
    mkdir -p ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}

    if [ -d "packages/${DISTRIBUTION}/one-click-install/" ]; then
        packages=(packages/${DISTRIBUTION}*/one-click-install/*.rpm)
    else
        packages=(packages/${DISTRIBUTION}*/*.rpm)
    fi

    for package in "${packages[@]}"; do
        cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
        package_name=$(rpm -qp --queryformat '%{NAME}' ${package})
        package_arch=$(rpm -qp --queryformat '%{ARCH}' ${package})
        cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_name}_${package_arch}.rpm
    done
}


####################
## Snap packaging ##
####################

function package_snap()
{
    echo "####################"
    echo "## deploying snap ##"
    echo "####################"

    if [[ "${CHANNEL:0:8}" == "internal" ]]; then
        DISTRIBUTION_REPOSITORY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
        mkdir -p ${DISTRIBUTION_REPOSITORY_FOLDER}
        ls packages/${DISTRIBUTION}*
        cp packages/${DISTRIBUTION}*/*.snap ${DISTRIBUTION_REPOSITORY_FOLDER}/
    elif [[ $CHANNEL =~ nightly ]]; then
        snapcraft whoami || true
        snapcraft logout || true
        export SNAPCRAFT_STORE_CREDENTIALS=$(cat /var/lib/jenkins/.snap/key)
        snapcraft login || true
        snapcraft whoami || true
        snapcraft push --verbose packages/${DISTRIBUTION}*/*.snap --release edge
    elif [[ $CHANNEL =~ stable ]]; then
        snapcraft push packages/${DISTRIBUTION}*/*.snap --release stable
    fi
}


################################################
## Deploy packages on given remote repository ##
################################################

function deploy()
{
    if [ -f "${SSH_IDENTITY_FILE}" ];
    then
        export RSYNC_RSH="ssh -i ${SSH_IDENTITY_FILE}"
    fi

    echo "##########################"
    echo "## deploying repository ##"
    echo "##########################"
    echo "Using RSYNC_RSH='${RSYNC_RSH}'"
    rsync --archive --recursive --verbose \
          --delete ${DISTRIBUTION_REPOSITORY_FOLDER} \
          ${REMOTE_REPOSITORY_LOCATION}

    echo "#####################################"
    echo "## deploying manual download files ##"
    echo "#####################################"
    rsync --archive --recursive --verbose \
          --delete ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER} \
          ${REMOTE_MANUAL_DOWNLOAD_LOCATION}
}


##########################################################
## Detect suitable packaging based on distribution name ##
##########################################################

function package()
{
    if [[ $DISTRIBUTION =~ debian|ubuntu|raspbian|guix-deb-pack ]]; then
        package_deb
    elif [[ $DISTRIBUTION =~ fedora|rhel|opensuse ]]; then
        package_rpm
    elif [[ $DISTRIBUTION =~ snap ]]; then
        package_snap
    else
        echo "error: Distribution \"$DISTRIBUTION\" is not supported"
    fi
}

function remove-deployed-files()
{
    # remove deployed files
    rm -rf manual-download
    rm -rf repositories
    rm -rf ${DISTRIBUTION_REPOSITORY_FOLDER}
}

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
    --remote-ssh-identity-file=*)
    SSH_IDENTITY_FILE="${i#*=}"
    shift
    ;;
    *)
    echo "Unrecognized option ${i}"
    exit 1
    ;;
esac
done


if [ -z "${KEYID}" ];
then
    DISTRIBUTION_REPOSITORY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
    DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER=$(realpath manual-download)/${DISTRIBUTION}
    deploy
    remove-deployed-files
else
    package
    deploy
fi
