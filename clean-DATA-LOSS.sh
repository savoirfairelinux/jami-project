#!/usr/bin/env bash
# Remove everything that is not git tracked on the submodules.
# May cause data loss.
git submodule foreach git clean -dfX
# sudo here because of: https://tuleap.ring.cx/plugins/tracker/?aid=301
sudo rm -rf install *.log *.pid
