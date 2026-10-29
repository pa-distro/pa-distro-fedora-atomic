#!/usr/bin/env bash
# Copia i file di sistema (locale, skel, branding) nella radice dell'immagine.
set -euxo pipefail

if [ -d /ctx/system_files ]; then
  cp -a /ctx/system_files/. /
fi

# Permessi home skeleton
if [ -d /etc/skel ]; then
  chmod 755 /etc/skel
fi

echo "03-files: ok"
