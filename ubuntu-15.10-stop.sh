#!/usr/bin/env bash
# Stop local install daemon and client that have been installed with the install script.
cd "$(dirname "${BASH_SOURCE[0]}")"
kill "$(cat client-gnome.pid)"
kill "$(cat daemon.pid)"
