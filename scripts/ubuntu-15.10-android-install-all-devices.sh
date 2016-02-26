#!/usr/bin/env bash
# Build the Android app and install it on all connected devices.
set -e
./ubuntu-15.10-dependencies.sh
cd client-android
./compile.sh
# TODO use gradlew instead.
# From: http://stackoverflow.com/questions/8610733/how-can-i-adb-install-an-apk-to-multiple-connected-devices
adb devices | tail -n +2 | cut -sf 1 | xargs -i'{}' adb -s '{}' install ring-android/app/build/outputs/apk/app-debug.apk
