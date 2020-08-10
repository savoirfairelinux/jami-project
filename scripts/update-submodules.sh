#!/usr/bin/env bash

git submodule foreach "git pull origin master"
git add client-android \
        client-gnome \
        client-ios \
        client-macosx \
        client-qt \
        client-uwp \
        daemon \
        lrc
git commit
