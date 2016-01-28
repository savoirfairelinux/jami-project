#!/usr/bin/env bash
# Remove everything that is not git tracked.
# May cause data loss.
git submodule foreach git clean -dfx
