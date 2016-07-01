Ring release process
====================

This page explains the process of making a new Ring release. It can be used as checklist of things to remember when making a new release. It was written to clarify the release process between the Ring dev team and the distribution maintainers.

Release tarball
###############

Ring is released in the form of a tarball. They are hosted here:

 - https://dl.ring.cx/ring-release/tarballs/

Tarballs are generated from the integration branch of the `ring-project <https://github.com/savoirfairelinux/ring-project>`_ repository with a job on our `Jenkins server <https://test.savoirfairelinux.com/>`_. They include a copy of all contrib libraries configured in ``daemon/contrib/src``. If you are a Savoir-faire Linux employee, you may trigger the job from `this page <https://test.savoirfairelinux.com/job/ring-release/>`_.

Naming scheme
-------------

Tarballs respect the following naming scheme ``ring_<date>_<number_of_commits>.<commit_id>.tar.gz`` where:

 - **date** is the current date, for example 20160422
 - **number_of_commits** represents the number of commits that day
 - **commit_id** is the commit id of the last ring-project commit


Packaging
#########

Distribution packaging
----------------------

Distribution packages should be generated from the release tarballs. It is best that distributions exclude as much embedded libraries as possible from the tarballs and use their packaged versions instead.

Debian
++++++

The Debian package is maintained by Alexandre Viau <aviau@debian.org> as part of the Debian VoIP Team <pkg-voip-maintainers@lists.alioth.debian.org>.

The packaging is maintained using git-buildpackage and can be found in the following Alioth repository:

- git.debian.org:/git/pkg-voip/ring.git


The repository contains a Debian.README file explaining the process of importing a new version. To upload a new version of Ring, manual action is required by Alexandre. If he is unavailable, other members of the Debian VoIP team may do the upload.

Upstream packaging
------------------

The Ring dev team builds packages for popular Linux distributions. Those packages are built weekly. Instructions on installing the repositories can be found on `ring.cx/download <https://ring.cx/en/download>`_.

Stable releases
###############

At this moment Ring is still considered in beta and does not support stable releases. This may or may not change when the beta period is over. The most secure and stable version of ring is the tip of the master branch.
