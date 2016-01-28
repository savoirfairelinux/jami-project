# Ring

Synchronization of all the repositories of <https://ring.cx/> through submodules, with scripts to build for each platform easily.

Fixes <https://tuleap.ring.cx/plugins/tracker/?aid=250>.

I'd rather have a single Git repo, but without official support, maintaining a single git repo is useless, so I'll start with submodules which are easier to put together.

## Ubuntu 15.10

    ./ubuntu-15.10.sh
    nohup ./install/daemon/libexec/dring >/dev/null &
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:install/lrc/lib" ./install/client-gnome/bin/gnome-ring
