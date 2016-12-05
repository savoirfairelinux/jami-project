#!/bin/bash

# Update SPARKLE_FILE with given executable
# Usage ./winsparkle-xml-updater.sh ring.exe <URI of winsparkle-ring.xml>

PACKAGE=$1
SPARKLE_SOURCE=$2
SPARKLE_FILE=winsparkle-ring.xml
TMP_FILE=winsparkle.tmp
REPO_URL=${2%/${SPARKLE_FILE}}


if [ ! -f ${PACKAGE} ]; then
    echo "Can't find package aborting..."
    exit 1
fi

if [ ! -s ${SPARKLE_FILE} ]; then

    wget --no-check-certificate --retry-connrefused --tries=20 --wait=2 \
         --random-wait --waitretry=10 ${SPARKLE_SOURCE} -O ${SPARKLE_FILE}

    if [ $? -eq 127 ]; then
        rm -f ${SPARKLE_FILE}
        COUNTER=0
        curl --retry 2 --retry-delay 2 ${SPARKLE_SOURCE} -o ${SPARKLE_FILE}
        until [ $? -eq 0 -o $COUNTER -gt 10 ]; do
            sleep 1
            let COUNTER=COUNTER+1
            curl --retry 2 --retry-delay 2 ${SPARKLE_SOURCE} -o ${SPARKLE_FILE}
        done

        if [ $? -ne 0 ]; then
            echo 'the winsparkle file have been badly overwriten; deleting it.'
            rm -f winsparkle.xml
            exit 1
        fi
    fi
fi

if [[ $(basename ${PACKAGE}) == *"x86_64"* ]]
then
    OS="windows-x64";
else
    OS="windows-x86";
fi

# update URI in <link> field
gawk -i inplace -v source="${SPARKLE_SOURCE}" '/<link>/{printf "        <link>";
                                                        printf source; print "</link>"; next}1' ${SPARKLE_FILE}


# update xml list with new image item

URL="${REPO_URL}/$(basename ${PACKAGE})"
LENGTH="$(stat -c %s ${PACKAGE})"
python3 ./scripts/winsparkle.py winsparkle-ring.xml "Ring nightly" ${URL} ${OS} ${LENGTH}
