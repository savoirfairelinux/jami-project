Just the gnome client (advanced)
================================

Requirements
############

- Ring daemon
- libRingClient
- GTK+3 (3.10 or higher)
- Qt5 Core
- X11
- gnome-icon-theme-symbolic (certain icons are used which other themes might be missing)
- libnotify (optional, if you wish to receive desktop notifications of incoming calls, etc)
- gettext (optional to compile translations)

On Debian/Ubuntu these can be installed with:

.. code-block:: bash

    sudo apt-get install g++ cmake libgtk-3-dev qtbase5-dev libclutter-gtk-1.0-dev gnome-icon-theme-symbolic libebook1.2-dev libnotify-dev gettext

On Fedora:

.. code-block:: bash

    sudo yum install gcc-c++ cmake gtk3-devel qt5-qtbase-devel clutter-gtk-devel gnome-icon-theme-symbolic libnotify-devel gettext

Compiling
#########

Run the following from the project root directory:

.. code-block:: bash

    mkdir build
    cd build
    cmake ..
    make

The following options are often useful to append to the cmake line:

.. code-block:: none

    -DCMAKE_INSTALL_PREFIX=<install location>
    -DLibRingClient_DIR=<path the the installed cmake module of LibRingClient>
    -DLibRingClient_PROJECT_DIR=<path to the project folder of LibRingClient>

You can then simply run ``./gnome-ring`` from the build directory

Installing
##########

If you're building the client for use (rather than testing of packaging), it is
recommended that you install it on your system, eg: in '/usr', '/usr/local', or
'/opt', depending on your distro's preference to get full functionality such as
desktop integration. In this case you should perform a 'make install' after
building the client.


Building without installing Ring daemon and libRingClient
#########################################################

It is possible to build ring-client-gnome without installing the daemon and
libRingClient on your system (eg: in /usr or /usr/local):

1. build the daemon
2. when building libRingClient, specify the location of the daemon lib in the
   cmake options with ``-DRING_BUILD_DIR=``, eg:
   ``-DRING_BUILD_DIR=/home/user/ring/daemon/src``
3. to get the proper headers, we still need to ``make install`` libRingClient, but
   we don't have to install it in /usr, so just specify another location for the
   install prefix in the cmake options, eg:
   ``-DCMAKE_INSTALL_PREFIX=/home/user/ringinstall``
4. compile libRingClient and do 'make install', everything will be installed
   in the dir specified by the prefix
4. point the client to the libRingClient cmake module during configuration:
   ``-DLibRingClient_DIR=/home/user/ringinstall/lib/cmake/LibRingClient``


Debugging
#########

For now, the build type of the client is "Debug" by default, however it is
useful to also have the debug symbols of libRingClient. To do this, specify this
when compiling libRingClient with ``-DCMAKE_BUILD_TYPE=Debug`` in the cmake
options.
