Setting up a TURN or STUN server
================================

Ring can be configured to use TURN or STUN servers (`RFC5766 <https://tools.ietf.org/html/rfc5766>`_) to establish a connection between two peers.

In this guide, we will setup a `coturn <https://github.com/coturn/coturn>`_ server. There are other TURN/STUN server implementations available under a free license. See `TurnServer <http://turnserver.sourceforge.net/>`_ and `Restund <http://www.creytiv.com/restund.html>`_.

1. Installing
#############

COTURN is available in most Linux distributions. On Debian, install it with the following command:

.. code-block:: bash

    apt-get install coturn

2. Configuring
##############

Here is a basic ``turnserver.conf`` file:

.. code-block:: none

    listening-port=10000
    listening-ip=0.0.0.0
    min-port=10000
    max-port=30000
    lt-cred-mech
    realm=sfl
    no-stun

3. Creating users on your TURN server
#####################################

To create users on your TURN server, use the ``turnadmin`` binary.

.. code-block:: bash

    turnadmin -a -u bob -p secretpassword -r sfl


4. Launching the TURN server
############################

.. code-block:: bash

    turnserver -c turnserver.conf


5. Configuring Ring to authenticate to the TURN server
######################################################

You may configure Ring to use your TURN server from the advanced tab your account settings:

============== ============================ ======================
   Field                 Value                   Example
============== ============================ ======================
**server url** host and port of your server 0.0.0.0:10000
**username**   username                     bob
**password**   password                     secretpassword
**realm**      realm                        sfl
============== ============================ ======================
