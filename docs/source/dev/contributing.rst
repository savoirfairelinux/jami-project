.. _contributing:

Contributing
============

Ring loves external contributions but we do not use the Github PR system.
Instead, we host a public gerrit server: https://gerrit-ring.savoirfairelinux.com

Before submitting a contribution, you need to register on our Gerrit server
either with your Github or Google account.

Head to the settings section to set one of the following:

- http password and username: https://gerrit-ring.savoirfairelinux.com/#/settings/http-password
- ssh key: https://gerrit-ring.savoirfairelinux.com/#/settings/ssh-keys

In each Ring submodule there is a ``.gitreview`` file. It contains all the
necessary info to send a patchset to our gerrit server.

After you commited your changes (one or multiple commits) you can submit them
with:

.. code-block:: bash

    git-review

More documentation on Gerrit can be found on the `official website <https://www.gerritcodereview.com/>`_.

Making Changes
##############

* [Optionnal] Create a ticket in our Tuleap bug tracker https://tuleap.ring.cx/projects/ring
* Make commits of logical units.
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format
    - 50 chars title
    - 80 chars message width
