#!/usr/bin/env bash

git submodule foreach "git pull origin master"
git add client-android client-gnome client-macosx client-windows daemon lrc
git commit
