#!/bin/bash

cd daemon/contrib
mkdir native
cd native

../bootstrap
make fetch-all
cd ..
rm -rf native

# Create tarball variables
cd ../..
lastcommitdate=`git log -1 --format=%cd --date=short` # YYYY-MM-DD
numbercommits=`git log --format=%cd --date=short | grep -c $lastcommitdate` # number of commits that day
dateshort=`echo $lastcommitdate | sed -s 's/-//g'` # YYYYMMDD
commitid=`git rev-parse --short HEAD` # last commit id

#create tarball
cd ..
tar --exclude-vcs -zcf ring_$dateshort.$numbercommits.$commitid.tar.gz ring-project
mv ring_$dateshort.$numbercommits.$commitid.tar.gz ring-project
