#!/usr/bin/env bash
# Abilitazione/disabilitazione servizi (offline).
set -euxo pipefail

systemctl enable firewalld.service
systemctl enable cups.service
systemctl disable sshd.service || true

# --- Ispirato a Parrot: meno servizi attivi di default ---
# Bluetooth: spento di default. Per riabilitarlo:
#   sudo systemctl unmask bluetooth.service && sudo systemctl enable --now bluetooth.service
systemctl disable bluetooth.service || true
systemctl mask bluetooth.service || true

# --- Setup di primo avvio: inutile su immutabile già configurato ---
# (la configurazione è nell'immagine / in disk_config/*.toml)
systemctl mask initial-setup.service || true
systemctl mask plasma-setup.service || true

echo "04-services: ok"
