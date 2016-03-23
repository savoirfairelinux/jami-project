# How to contribute

Ring loves external contributions. But we do not use Github PR system.
Instead we host a public gerrit server.

    https://gerrit-ring.savoirfairelinux.com

More documentation on Gerrit:

    https://www.gerritcodereview.com/

In each Ring modules there is a .gitreview file. It contains all the
necessary info to send a patchset to our gerrit.

#### Example:
    [gerrit]
    host=gerrit-ring.savoirfairelinux.com
    port=29420
    project=ring-daemon.git
    defaultremote=origin
    defaultbranch=master

After you commited your changes (one or multiple commits) you only
need to submit them with:

    git-review

## Making Changes

* [Optionnal] Create a ticket in our Tuleap bug tracker https://tuleap.ring.cx/projects/ring
* Make commits of logical units.
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format
    - 50 chars title
    - 80 chars message width
