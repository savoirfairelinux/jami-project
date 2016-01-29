# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

Fixes <https://tuleap.ring.cx/plugins/tracker/?aid=250>.

I'd rather have a single Git repo, but without official support, maintaining a merged single git repo is useless, so I'll start with submodules which are easier to paste together.

## Ubuntu 15.10

Build and install locally under this repository:

    ./ubuntu-15.10-local-install.sh

Run daemon and client on background:

    ./ubuntu-15.10-run.sh

Stop daemon and client:

    ./ubuntu-15.10-stop.sh
