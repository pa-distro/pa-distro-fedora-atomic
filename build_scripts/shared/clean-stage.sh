#!/usr/bin/env bash
# Pulizia degli stage temporanei (script/file non devono restare nell'immagine).
# Nota: /ctx è un bind mount read-only, non va rimosso.
set -euxo pipefail

rm -rf /tmp/* /var/tmp/* || true
dnf clean all || true

echo "clean-stage: ok"
