#!/usr/bin/env bash
# Abilitazione/disabilitazione servizi (offline).
set -euxo pipefail

systemctl enable firewalld.service
systemctl enable cups.service
systemctl disable sshd.service || true

# Bluetooth: decompmenta se non servono periferiche BT
# systemctl disable bluetooth.service || true

echo "04-services: ok"
