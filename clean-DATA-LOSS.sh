#!/usr/bin/env bash
# Remove everything that is not git tracked on the submodules.
# May cause data loss.
git submodule foreach git clean -dffX
rm -rf install *.log *.pid
