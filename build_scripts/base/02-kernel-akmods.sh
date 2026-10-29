#!/usr/bin/env bash
# Kernel: nella versione slim usiamo quello della base Kinoite.
# (Aurora installa un kernel dagli stage akmods; qui non serve.)
set -euxo pipefail

echo "Kernel dalla base:"
rpm -q kernel-core || true

echo "02-kernel-akmods: nessun akmods (slim build)"
