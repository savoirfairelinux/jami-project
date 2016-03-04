# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

## First thing first

    git submodule update --init

## Install python3

Ring installer uses python3. Please make sure it is installed before running it.

## Using make-ring.py

Build and install all the dependencies:

    ./ring-build --dependencies

#### Linux
    Your distro package manager will be used.

#### OSX
    You need to setup Homebrew (http://brew.sh/) since their is no built-in package manager on OSX.

Build and install locally under this repository:

    ./make-ring.py --install

Run daemon and client that were installed locally:

    ./make-ring.py --run

You can then stop the processes with CTRL-C.

_On Linux_ You can also run them in the background with the `--background` argument and then use the `--stop` command to stop them.
Stdout and stderr go to `daemon.log` and `client-gnome.log`.

Install globally for all users instead:

    ./make-ring.py --install --global-install

Run global install:

    gnome-ring

This already starts the daemon automatically for us.

Uninstall the global install:

    ./make-ring.py --uninstall

## Outputs

#### Linux

#### OSX

You can find the .app file in the ./install/client-macosx folder.


## Ubuntu 15.10 host Android device

This script does not automate the installation of any Android development tools.

First ensure that you can build and install a minimal Android App on your device, e.g. <https://github.com/cirosantilli/android-cheat/tree/214fab34bb0e1627ac73e43b72dee7d1f8db7bfb/min>

This will at least require installing the SDK.

All executables used must be in your `PATH`, e.g. `adb`.

Then build and install on all connected devices with:

    ./scripts/ubuntu-15.10-android-install-all-devices.sh
