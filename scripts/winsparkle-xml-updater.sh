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
    if [ $? -ne 0 ]; then
        echo 'the winsparkle file have been badly overwriten; deleting it.'
        rm -f winsparkle.xml
        exit 1
    fi
fi

if [[ $(basename ${PACKAGE}) == *"x86_64"* ]]
then
    OS="windows-x64";
else
    OS="windows-x86";
fi

#update URI in <link> field
gawk -i inplace -v source="${SPARKLE_SOURCE}" '/<link>/{printf "        <link>";
                                                        printf source; print "</link>"; next}1' ${SPARKLE_FILE}


#update list with new image item
cat << EOS > ${TMP_FILE}
        <item>
            <title>Ring nightly $(date "+%Y/%m/%d %H:%M")</title>
            <pubDate>$(date -R)</pubDate>
            <enclosure url="${REPO_URL}/$(basename ${PACKAGE})" sparkle:version="$(date +%Y%m%d)" sparkle:shortVersionString="nightly-$(date "+%Y%m%d")" sparkle:os="${OS}" length="$(stat -c %s ${PACKAGE})" type="application/octet-stream" />
        </item>
EOS

if [ -s ${SPARKLE_FILE} ];then
    gawk -i inplace -v tmp="${TMP_FILE}" '/language/{print; while(getline line < tmp){print line};close(tmp);next}1' ${SPARKLE_FILE}
    rm -f ${TMP_FILE}
else
    echo 'empty SPARKLE_FILE'
    rm -f ${TMP_FILE}
    exit 1
fi
