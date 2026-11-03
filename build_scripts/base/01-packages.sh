#!/usr/bin/env bash
# Pacchetti dell'immagine PA (variante Aurora-style).
set -euxo pipefail

# --- RPM Fusion (free + nonfree): codec ---
dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# --- Pacchetti base + ufficio + firma + sicurezza ---
dnf install -y --setopt=install_weak_deps=False \
  libreoffice \
  libreoffice-langpack-it \
  thunderbird \
  firefox \
  okular \
  tesseract \
  tesseract-langpack-ita \
  simple-scan \
  pcsc-lite \
  pcsc-tools \
  ccid \
  opensc \
  shared-mime-info \
  firewalld \
  cups \
  system-config-printer \
  keepassxc \
  usbguard \
  gstreamer1-plugins-bad-freeworld \
  gstreamer1-plugins-ugly \
  rsync \
  nano \
  vim \
  htop \
  unzip \
  p7zip \
  p7zip-plugins \
  desktop-file-utils \
  zsh \
  fastfetch \
  btop \
  source-foundry-hack-fonts \
  gtk-update-icon-cache

# --- Rimozioni non critiche (best effort, non fallisce se assenti) ---
# initial-setup / plasma-setup: su immutabile la configurazione è già nell'immagine,
# quindi il wizard di primo avvio non serve (ispirato a Parrot: meno servizi, meno attrito).
dnf -y remove \
  abrt abrt-desktop rsyslog \
  initial-setup plasma-setup \
  || true

# --- AD/LDAP (opzionale: decommenta se serve il join al dominio) ---
# dnf install -y \
#   realmd sssd sssd-tools adcli oddjob oddjob-mkhomedir \
#   samba-common-tools krb5-workstation authselect

dnf clean all
echo "01-packages: ok"
