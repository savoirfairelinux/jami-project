#!/usr/bin/env bash
# Uninstall a global install.
sudo make -C daemon uninstall
sudo xargs rm < lrc/build/install_manifest.txt
sudo xargs rm < client-gnome/build/install_manifest.txt
