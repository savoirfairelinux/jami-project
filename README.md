# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

Fixes <https://tuleap.ring.cx/plugins/tracker/?aid=250>.

I'd rather have a single Git repo, but without official support, maintaining a merged single git repo is useless, so I'll start with submodules which are easier to paste together.

## Ubuntu 15.10

Build and install locally under this repository:

    ./ubuntu-15.10-install.sh

Run daemon and client that were installed locally on the background:

    ./ubuntu-15.10-run.sh

Stdout and stderr go to `daemon.log` and `client-gnome.log`.

Stop daemon and client:

    ./ubuntu-15.10-stop.sh

Install globally for all users instead:

    ./ubuntu-15.10-install.sh -g

Run global install:

    gnome-ring

This already starts the daemon for us.

## Ubuntu 15.10 host Android device

This script does not automate the installation of any Android development tools.

First ensure that you can build and install a minimal Android App on your device, e.g. <https://github.com/cirosantilli/android-cheat/tree/214fab34bb0e1627ac73e43b72dee7d1f8db7bfb/min>

This will at least require installing the SDK.

All executables used must be in your `PATH`, e.g. `adb`.

Then build and install on all connected devices with:

    ./ubuntu-15.10-android-install-all-devices.sh
