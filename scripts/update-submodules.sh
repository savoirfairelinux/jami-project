#!/usr/bin/env bash

git submodule foreach "git pull origin master"
git add client-android \
        client-ios \
        client-macosx \
        client-qt \
        client-uwp \
        daemon \
        lrc \
        plugins
git commit
