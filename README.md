# Ring

Synchronization via submodules of the repositories of <https://ring.cx/> to states in which they work together + scripts to build for each platform easily.

## Install python3

Ring installer uses python3. Please make sure it is installed before running it.

## First thing first

    ./make-ring.py --init

## On Linux

#### Build and install all the dependencies:

    ./make-ring.py --dependencies

Your distro package manager will be used.

#### Build and install locally under this repository:

    ./make-ring.py --install

#### Run daemon and client that were installed locally:

	./make-ring.py --run
You can then stop the processes with CTRL-C.

You can also run them in the background with the --background argument and then use the --stop command to stop them. Stdout and stderr go to daemon.log and client-gnome.log.

#### Install globally for all users instead:

    ./make-ring.py --install --global-install

#### Run global install:

    gnome-ring

This already starts the daemon automatically for us.

#### Uninstall the global install:

    ./make-ring.py --uninstall

## On OSX

You need to setup Homebrew (<http://brew.sh/>) since their is no built-in package manager on OSX.

#### Build and install all the dependencies:

    ./make-ring.py --dependencies


#### Build and install locally under this repository:

    ./make-ring.py --install

#### Output

You can find the .app file in the ./install/client-macosx folder.

## On Android

Please make sure you have the Android SDK and NDK installed, and that their paths are properly set. For further information, please visit <https://github.com/savoirfairelinux/ring-client-android>

#### Build and install locally under this repository:

    ./make-ring.py --install --distribution=Android

#### Output

You can find the .apk file in the ./client-android/ring-android/app/build/outputs
