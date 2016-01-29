#!/usr/bin/env bash
# Run local install daemon and client that have\
# been installed with the install script on the background.
./install/daemon/libexec/dring 2>&1 >>daemon.log &
echo $! >daemon.pid
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring 2>&1 >>client-gnome.log &
echo $! >client-gnome.pid
