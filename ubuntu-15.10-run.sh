#!/usr/bin/env bash
# Run local install daemon and client that have
# been installed with the install script on the background.
cd "$(dirname "${BASH_SOURCE[0]}")"
(echo 'Starting daemon.'; date) >>daemon.log
./install/daemon/libexec/dring -c -d >>daemon.log 2>&1 &
echo $! >daemon.pid
(echo 'Starting client;'; date) >>client-gnome.log
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring -d >>client-gnome.log 2>&1 &
echo $! >client-gnome.pid
