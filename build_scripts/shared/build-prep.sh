#!/usr/bin/env bash
# Preparazione comune del build.
set -euxo pipefail

# Alcuni pacchetti/script si aspettano /var/roothome
mkdir -p /var/roothome

# Assicura le directory standard
mkdir -p /var/tmp
chmod 1777 /var/tmp

echo "build-prep: ok ($(rpm -E %fedora))"
