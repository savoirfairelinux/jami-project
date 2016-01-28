# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

Fixes <https://tuleap.ring.cx/plugins/tracker/?aid=250>.

I'd rather have a single Git repo, but without official support, maintaining a merged single git repo is useless, so I'll start with submodules which are easier to paste together.

## Ubuntu 15.10

Build, install locally under this repository, and run that local install:

    ./ubuntu-15.10-local-install.sh
    nohup ./install/daemon/libexec/dring >/dev/null &
    DRING_PID=$!
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring

To stop, hit: `Ctrl + C` to kill the client and:

    kill $DRING_PID

for the server.
