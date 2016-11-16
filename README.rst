ring-project
============

This repository is the master repository for Ring. It contains a build script, make-ring.py,
that can be used to build and install ring from source on different platforms.

More documentation can be found on http://docs.ring.cx. You may also build the documentation
with ``make docs``. The documentation will be built in ``docs/build/html``.

Using make-ring
###############

Dependencies
------------

The Ring installer uses python3. Please make sure it is installed before running it.

Initialize the repositories
---------------------------

.. code-block:: bash

    ./make-ring.py --init

It initializes and updates the submodules to set them at the top of their master branch. This
is ideal to have the latest development version.

However, in order to build a specific version of Ring, such as the Production one, please use

.. code-block:: bash

    git submodule update --init

On Linux
--------

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
''''''''''''''''''''''''''''''''''''''

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
------

You need to setup Homebrew (<http://brew.sh/>) since their is no built-in package manager on OSX.

Build and install all the dependencies:

.. code-block:: bash

    ./make-ring.py --dependencies


Build and install locally under this repository:

.. code-block:: bash

    ./make-ring.py --install

Output
''''''

You can find the .app file in the ``./install/client-macosx`` folder.

On Android
----------

Please make sure you have the Android SDK and NDK installed, and that their paths are properly set. For further information, please visit <https://github.com/savoirfairelinux/ring-client-android>

Build and install locally under this repository:

.. code-block:: bash

    ./make-ring.py --install --distribution=Android

Output
''''''

You can find the .apk file in the ./client-android/ring-android/app/build/outputs
