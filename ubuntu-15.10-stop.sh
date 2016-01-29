#!/usr/bin/env bash
# Stop local install daemon and client that have been installed with the install script.
kill "$(cat client-gnome.pid)"
kill "$(cat daemon.pid)"
