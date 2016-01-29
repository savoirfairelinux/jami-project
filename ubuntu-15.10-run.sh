#!/usr/bin/env bash
# Run local install daemon and client that have\
# been installed with the install script on the background.
./install/daemon/libexec/dring >>daemon.log 2>&1 &
echo $! >daemon.pid
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring >>client-gnome.log 2>&1 &
echo $! >client-gnome.pid
