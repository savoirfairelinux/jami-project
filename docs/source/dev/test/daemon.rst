Test the daemon
===============

The unit testing framework
##########################
We use CppUnit on GNU ring project. You can find a simple tutorial with code example on the  `official website <http://cppunit.sourceforge.net/doc/cvs/cppunit_cookbook.html>`_.

Tests
#####
How to use them?
----------------
Write "make check" instead of "make".


Localisation
------------
All the tests are locate on the test folder:

- Black box test are locate at the root of the folder
- Unit tests are locate in the unitTest folder with the same path as the class you test on the src folder (`simple example <https://gerrit-ring.savoirfairelinux.com/#/c/7677/>`_)
