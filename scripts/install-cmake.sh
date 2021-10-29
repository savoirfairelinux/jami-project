#!/usr/bin/env bash

set -e

if command -v apt-get &> /dev/null
then
    apt-get remove cmake cmake-data -y
fi

wget https://github.com/Kitware/CMake/releases/download/v3.19.8/cmake-3.19.8-Linux-x86_64.sh \
      -q -O /tmp/cmake-install.sh
echo "aa5a0e0dd5594b7fd7c107a001a2bfb5f83d9b5d89cf4acabf423c5d977863ad  /tmp/cmake-install.sh" | sha256sum --check 
chmod u+x /tmp/cmake-install.sh
/tmp/cmake-install.sh --skip-license --prefix=/usr/local/
rm /tmp/cmake-install.sh