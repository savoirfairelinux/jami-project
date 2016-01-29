#!/usr/bin/env bash
# Build the Android app and install it on all connected devices.
cd client-android
./compile.sh
# From: http://stackoverflow.com/questions/8610733/how-can-i-adb-install-an-apk-to-multiple-connected-devices
adb devices | tail -n +2 | cut -sf 1 | xargs -i'{}' adb -s '{}' install ring-android/app/build/outputs/apk/app-debug.apk
