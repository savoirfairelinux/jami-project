#!/bin/bash
#
# Copyright (C) 2016-2017 Savoir-faire Linux Inc.
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
# This script sings and deploys pacakges from packages/distro.
# It should be ran from the project root directory.
#

# Exit immediately if a command exits with a non-zero status
set -e

###############################
## Debian / Ubuntu packaging ##
###############################

function package_deb()
{
    ##################################################
    ## Create local repository for the given distro ##
    ##################################################
    echo "#########################"
    echo "## Creating repository ##"
    echo "#########################"

    DISTRIBUTION_REPOSITOIRY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
    rm -rf ${DISTRIBUTION_REPOSITOIRY_FOLDER}
    mkdir -p ${DISTRIBUTION_REPOSITOIRY_FOLDER}/conf

    # Distributions file
    cat << EOF > ${DISTRIBUTION_REPOSITOIRY_FOLDER}/conf/distributions
Origin: ring
Label: Ring ${DISTRIBUTION} Repository
Codename: ring
Architectures: i386 amd64 armhf arm64
Components: main
Description: This repository contains Ring ${DISTRIBUTION} packages
SignWith: ${KEYID}
EOF

    # Options file
    cat << EOF > ${DISTRIBUTION_REPOSITOIRY_FOLDER}/conf/options
basedir ${DISTRIBUTION_REPOSITOIRY_FOLDER}
EOF

    ####################################
    ## Add packages to the repository ##
    ####################################

    for package in packages/${DISTRIBUTION}*/*.deb; do

        # Sign the deb
        echo "## signing: ${package} ##"
        dpkg-sig -k ${KEYID} --sign builder ${package}

        # Include the deb
        echo "## including ${package} ##"
        package_name=$(dpkg -I ${package} | grep -m 1 Package: | awk '{print $2}')
        package_arch=$(dpkg -I ${package} | grep -m 1 Architecture: | awk '{print $2}')
        if [ ${package_arch} = "all" ]; then
            # Removing to avoid the error of adding the same deb twice.
            # This happens with arch all packages, which are generated in amd64 and i386.
            reprepro --verbose --basedir ${DISTRIBUTION_REPOSITOIRY_FOLDER} remove ring ${package_name}
        fi
        reprepro --verbose --basedir ${DISTRIBUTION_REPOSITOIRY_FOLDER} includedeb ring ${package}
    done

    # Rebuild the index
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITOIRY_FOLDER} export ring

    # Show the contents
    reprepro --verbose --basedir ${DISTRIBUTION_REPOSITOIRY_FOLDER} list ring

    #######################################
    ## create the manual download folder ##
    #######################################
    if ls packages/${DISTRIBUTION}*_oci &> /dev/null; then
      DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER=$(realpath manual-download)/${DISTRIBUTION}
      mkdir -p ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
      NAME_PATTERN=jami-all_????????.*\~dfsg*.deb
      cp packages/${DISTRIBUTION}*_oci/${NAME_PATTERN} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
      for package in ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${NAME_PATTERN} ; do
          package_name=$(dpkg -I ${package} | grep -m 1 Package: | awk '{print $2}')
          package_arch=$(dpkg -I ${package} | grep -m 1 Architecture: | awk '{print $2}')
          package_shortname=${package_name}_${package_arch}.deb
          rm -f ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_shortname}
          cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_shortname}
      done
    else
      echo "WARNING: OCI packages directory not found"
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

    DISTRIBUTION_REPOSITOIRY_FOLDER=$(realpath repositories)/${DISTRIBUTION}
    rm -rf ${DISTRIBUTION_REPOSITOIRY_FOLDER}
    mkdir -p ${DISTRIBUTION_REPOSITOIRY_FOLDER}

    # .repo file
    cat << EOF > ${DISTRIBUTION_REPOSITOIRY_FOLDER}/ring-nightly.repo
[ring]
name=Ring \$releasever - \$basearch - ring
baseurl=https://dl.jami.net/ring-nightly/${DISTRIBUTION%_*}_\$releasever
gpgcheck=1
gpgkey=https://dl.jami.net/ring.pub.key
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
    if [ -d "packages/${DISTRIBUTION}/one-click-install/" ];
    then
        for package in packages/${DISTRIBUTION}*/one-click-install/*.rpm; do
            cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
            package_name=$(rpm -qp --queryformat '%{NAME}' ${package})
            package_arch=$(rpm -qp --queryformat '%{ARCH}' ${package})
            cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_name}_${package_arch}.rpm
        done
    else
        for package in packages/${DISTRIBUTION}*/*.rpm; do
            cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}
            package_name=$(rpm -qp --queryformat '%{NAME}' ${package})
            package_arch=$(rpm -qp --queryformat '%{ARCH}' ${package})
            cp ${package} ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER}/${package_name}_${package_arch}.rpm
        done
    fi
}


################################################
## Deploy packages on given remote repository ##
################################################

function deploy()
{
    if [ -f "${SSH_IDENTIY_FILE}" ];
    then
        RSYNC_RSH="ssh -i ${SSH_IDENTIY_FILE}"
    fi

    # Deploy the repository
    echo "##########################"
    echo "## deploying repository ##"
    echo "##########################"
    echo "Using RSYNC_RSH='${RSYNC_RSH}'"
    rsync --archive --recursive --verbose --delete ${DISTRIBUTION_REPOSITOIRY_FOLDER} ${REMOTE_REPOSITORY_LOCATION}

    # deploy the manual download files
    echo "#####################################"
    echo "## deploying manual download files ##"
    echo "#####################################"
    rsync --archive --recursive --verbose --delete ${DISTRIBUTION_MANUAL_DOWNLOAD_FOLDER} ${REMOTE_MANUAL_DOWNLOAD_LOCATION}

    # remove deployed files
    rm -rf manual-download
    rm -rf repositories
}


##########################################################
## Detect suitable packaging based on distribution name ##
##########################################################

function package()
{
    if [[ "${DISTRIBUTION:0:6}" == "debian" || "${DISTRIBUTION:0:6}" == "ubuntu" || "${DISTRIBUTION:0:8}" == "raspbian" ]];
    then
        package_deb
    elif [[ "${DISTRIBUTION:0:6}" == "fedora" || "${DISTRIBUTION:0:4}" == "rhel" || "${DISTRIBUTION:0:13}" == "opensuse-leap" ]];
    then
        package_rpm
    else
        echo "ERROR: Distribution '${DISTRIBUTION}' is unsupported"
    fi
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
    SSH_IDENTIY_FILE="${i#*=}"
    shift
    ;;
    *)
    echo "Unrecognized option ${i}"
    exit 1
    ;;
esac
done

package
deploy
