#!/usr/bin/env bash
# Run local install daemon and client that have
# been installed with the install script on the background.
#
# Options:
#
# - d: run the daemon on a debugger in the foreground.
set -ex
debug=false
while getopts d OPT; do
  case "$OPT" in
    d)
      debug='true'
    ;;
    \?)
      exit 1
    ;;
  esac
done
cd "$(dirname "${BASH_SOURCE[0]}")"
(echo 'Starting daemon.'; date) >>daemon.log
if ! $debug; then
  ./install/daemon/libexec/dring -c -d >>daemon.log 2>&1 &
  echo $! >daemon.pid
fi
(echo 'Starting client;'; date) >>client-gnome.log
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring -d >>client-gnome.log 2>&1 &
echo $! >client-gnome.pid
if $debug; then
  gdb -p "$(cat daemon.pid)" -x gdb.gdb
fi
