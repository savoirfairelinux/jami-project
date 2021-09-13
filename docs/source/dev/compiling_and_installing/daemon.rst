Just the daemon (advanced)
==========================

Linux
#####

1. Compile the dependencies
---------------------------

.. code-block:: bash

    cd contrib
    mkdir native
    cd native
    ../bootstrap
    make

2. Compiling jamid
------------------

.. code-block:: bash

    cd ../../
    ./autogen.sh
    ./configure
    make

3. Installing jamid
-------------------

.. code-block:: bash

    make install

**Done !**

OSX
###

1. Installing dependencies
--------------------------

**Without a package manager**

.. code-block:: bash

    cd extras/tools
    ./bootstrap
    make
    export PATH=$PATH:/location/of/ring/daemon/extras/tools/build/bin

**With a package manager (macports or brew)**

Install the following:
 - automake
 - pkg-config
 - libtool
 - gettext
 - yasm


2. Compiling dependencies
-------------------------

.. code-block:: bash

    cd contrib
    mkdir native
    cd native
    ../bootstrap
    make -j

3. Compiling the daemon
-----------------------

.. code-block:: bash

    cd ../../
    ./autogen.sh
    ./configure  --without-dbus --prefix=<install_path>
    make

If you want to link against libringclient and native client easiest way is to
add to ./configure: ``--prefix=<prefix_path>``

**Done!**

Common Issues
-------------

``autopoint not found:`` When using Homebrew, autopoint is not found even when
gettext is installed, because symlinks are not created.
Run: ``brew link --force gettext`` to fix it.


Clang compatibility (developers only)
-------------------------------------

It is possible to compile jamid with Clang by setting CC and CXX variables
to 'clang' and 'clang++' respectively when calling ./configure.

Currently it is not possible to use the DBus interface mechanism, and the
interaction between daemon and client will not work; for each platform where
dbus is not available the client should implement all the methods in the
*_stub.cpp files.
