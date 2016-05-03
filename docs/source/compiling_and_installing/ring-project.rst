Building Using the make-ring script (recommended)
================================================

If you are reading this from the README.rst page, more documentation can be found on
https://ring.readthedocs.io/. You may also build the documentation with ``make docs``.
The documentation will be built in ``docs/build/html``.

Dependencies
############

The Ring installer uses python3. Please make sure it is installed before running it.

Initialize the repositories
###########################

.. code-block:: bash

    ./make-ring.py --init

On Linux
########

1. Build and install all the dependencies:

.. code-block:: bash

    ./make-ring.py --dependencies

Your distribution's package manager will be used.

2. Build and install locally under this repository:

.. code-block:: bash

    ./make-ring.py --install

3. Run daemon and client that were installed locally:

.. code-block:: bash

	./make-ring.py --run

You can then stop the processes with CTRL-C.

You can also run them in the background with the ``--background`` argument and then use the ``--stop`` command to stop them. Stdout and stderr go to daemon.log and client-gnome.log.

Install globally for all users instead
--------------------------------------

.. code-block:: bash

    ./make-ring.py --install --global-install

Run global install:

.. code-block:: bash

    gnome-ring

This already starts the daemon automatically for us.

Uninstall the global install:

.. code-block:: bash

    ./make-ring.py --uninstall

On OSX
######

You need to setup Homebrew (<http://brew.sh/>) since their is no built-in package manager on OSX.

Build and install all the dependencies:

.. code-block:: bash

    ./make-ring.py --dependencies


Build and install locally under this repository:

.. code-block:: bash

    ./make-ring.py --install

Output
------

You can find the .app file in the ``./install/client-macosx`` folder.

On Android
##########

Please make sure you have the Android SDK and NDK installed, and that their paths are properly set. For further information, please visit <https://github.com/savoirfairelinux/ring-client-android>

Build and install locally under this repository:

.. code-block:: bash

    ./make-ring.py --install --distribution=Android

Output
------

You can find the .apk file in the ./client-android/ring-android/app/build/outputs
