#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RING_PROJECT=$(realpath ${DIR}/..)

# Download contrib tarballs
cd ${RING_PROJECT}/daemon/contrib
mkdir native
cd native
../bootstrap
make fetch-all
cd ..
rm -rf native

# Create tarball variables
cd ${RING_PROJECT}
lastcommitdate=`git log -1 --format=%cd --date=short` # YYYY-MM-DD
numbercommits=`git log --format=%cd --date=short | grep -c $lastcommitdate` # number of commits that day
dateshort=`echo $lastcommitdate | sed -s 's/-//g'` # YYYYMMDD
commitid=`git rev-parse --short HEAD` # last commit id

# Create tarball
tmpdir=$(mktemp -d)
cd ${tmpdir}
tar -C ${RING_PROJECT}/.. --exclude-vcs -zcf ring_$dateshort.$numbercommits.$commitid.tar.gz $(basename ${RING_PROJECT})
mv ring_$dateshort.$numbercommits.$commitid.tar.gz ${RING_PROJECT}

# Cleanup contrib tarballs
rm -rf ${RING_PROJECT}/daemon/contrib/tarballs
