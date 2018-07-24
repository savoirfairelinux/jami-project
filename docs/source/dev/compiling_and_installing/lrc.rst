Just libRingClient (advanced)
=============================

Basic Installation
------------------

These are generic installation instructions.

To install the appplication, type the following commands in a console, while in the root directory of this application:

.. code-block:: bash

    mkdir -p build
    cd build
    cmake ..
    make -j3
    make install

The following options are often useful to append to the cmake line:

.. code-block:: none

    -DRING_BUILD_DIR=<daemon install location>
    -DCMAKE_INSTALL_PREFIX=<install location>
    -DRING_XML_INTERFACES_DIR=<daemon dbus interface definitions directory>
    -DCMAKE_BUILD_TYPE=<Debug to compile with debug symbols>
    -DENABLE_VIDEO=<False to disable video support>

Explanation
-----------

This script will configure and prepare the compilation and installation of the program and correctly link it against Ring daemon.

All needed files will be built in "build" directory.
So you have to go to this directory:

.. code-block:: bash

	cd build

Then execute the Makefile, to compile the application (src, doc...)

.. code-block:: bash

	make

Then install it all using:

.. code-block:: bash

	make install

You have to use "sudo" to be able to install the program in a protected directory (which is the case by default and most of the time).
Therefore it will ask for your system password.

OS X Install
------------

Install necessary tools:

.. code-block:: bash

	brew install cmake
	brew install qt5
	export CMAKE_PREFIX_PATH=<path_to_qt5>

hint: default install location with HomeBrew is /usr/local/Cellar/qt5

First make sure you have built ring daemon for OS X.

.. code-block:: bash

	mkdir build && cd build
	cmake .. -DCMAKE_INSTALL_PREFIX=<install_dir_of_daemon> [-DCMAKE_BUILD_TYPE=Debug for compiling with debug symbols]
	make install

You can now link and build the OSX client with Ring daemon and LRC library

Internationalization
--------------------

To regenerate strings for translations we use lupdate (within root of the project)

``lupdate ./src/ -source-language en -ts translations/lrc_en.ts``

Hint: On OSX lupdate is installed with Qt in /usr/local/Cellar/qt5/5.5.0/bin/ when installed with HomeBrew
