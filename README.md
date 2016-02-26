# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

Fixes <https://tuleap.ring.cx/plugins/tracker/?aid=250>.

I'd rather have a single Git repo, but without official support, maintaining a merged single git repo is useless, so I'll start with submodules which are easier to paste together.

## Using the build script

Build and install locally under this repository:

    ./build --install

Run daemon and client that were installed locally.

    ./build --run

You can then stop the processes with CTRL-C. You can also run them in the background with the `--background` argument and then use the `--stop` command to stop them. Stdout and stderr go to `daemon.log` and `client-gnome.log`.

Install globally for all users instead:

    ./build --install --global-install

Run global install:

    gnome-ring

This already starts the daemon automatically for us.

Uninstall the global install:

    ./build --uninstall

## Ubuntu 15.10 host Android device

This script does not automate the installation of any Android development tools.

First ensure that you can build and install a minimal Android App on your device, e.g. <https://github.com/cirosantilli/android-cheat/tree/214fab34bb0e1627ac73e43b72dee7d1f8db7bfb/min>

This will at least require installing the SDK.

All executables used must be in your `PATH`, e.g. `adb`.

Then build and install on all connected devices with:

    ./scripts/ubuntu-15.10-android-install-all-devices.sh
