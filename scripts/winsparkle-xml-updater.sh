#!/bin/bash

# Update SPARKLE_FILE with given executable
# Usage ./winsparkle-xml-updater.sh ring.exe <URI of winsparkle-ring.xml>

PACKAGE=$1
SPARKLE_SOURCE=$2
SPARKLE_FILE=winsparkle-ring.xml

if [ ! -f ${PACKAGE} ]; then
    echo "Can't find package aborting..."
    exit 1
fi

if [ ! -f ${SPARKLE_FILE} ]; then
    wget ${SPARKLE_SOURCE} -O ${SPARKLE_FILE}
fi

if [ -f ${SPARKLE_FILE} ]; then
    ITEMS=$(sed -n "/<item>/,/<\/item>/p" ${SPARKLE_FILE})
fi

if [[ $(basename ${PACKAGE}) == *"x86_64"* ]]
then
    OS="windows-x64";
else
    OS="windows-x86";
fi

cat << EOFILE > ${SPARKLE_FILE}
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Ring - weekly</title>
        <link>${REPO_URL}/${SPARKLE_FILE}</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
            <title>Ring nightly $(date "+%Y/%m/%d %H:%M")</title>
            <pubDate>$(date -R)</pubDate>
            <enclosure url="${REPO_URL}/$(basename ${PACKAGE})" sparkle:version="$(date +%Y%m%d)" sparkle:shortVersionString="nightly-$(date "+%Y%m%d")" sparkle:os="${OS}" length="$(stat -c %s ${PACKAGE})" type="application/octet-stream" />
        </item>
$(echo -e "${ITEMS}")
    </channel>
</rss>
EOFILE

