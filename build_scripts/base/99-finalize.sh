#!/usr/bin/env bash
# Pulizia finale prima del lint.
# Ordine importante: prima dnf clean (che scrive i log), poi si cancellano i log.
set -euxo pipefail

# 1) dnf clean PRIMA di rimuovere i log
dnf clean all || true

# 2) /run (runtime-only) e /tmp
rm -rf /run/* /run/.[!.]* 2>/dev/null || true
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

# 3) Log di build (dopo dnf clean)
rm -rf /var/log/* /var/log/.[!.]* 2>/dev/null || true

# 4) Stato dnf / firebird / ldconfig / viminfo non dichiarato in tmpfiles.d
rm -rf /var/lib/dnf 2>/dev/null || true
rm -rf /var/lib/firebird 2>/dev/null || true
rm -rf /var/cache/ldconfig 2>/dev/null || true
rm -f /var/roothome/.viminfo 2>/dev/null || true

echo "99-finalize: ok"
