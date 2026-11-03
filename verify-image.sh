#!/usr/bin/env bash
# verify-image.sh — verifica automatica dell'immagine PA (variante Aurora-style)
#
# Uso:
#   ./verify-image.sh [immagine]
#   ./verify-image.sh localhost/pa-desktop-aurora:latest
#
# Esce 0 se tutti i controlli bloccanti passano, 1 altrimenti.

set -uo pipefail

IMAGE="${1:-localhost/pa-desktop-aurora:latest}"

if ! podman image exists "$IMAGE"; then
  echo "❌ Immagine non trovata: $IMAGE"
  echo "   Esegui prima: just build"
  exit 2
fi

report=$(podman run --rm -i "$IMAGE" bash -s <<'EOS'
pass() { echo "PASS|$1"; }
fail() { echo "FAIL|$1"; }
info() { echo "INFO|$1"; }

# --- Base ---
grep -q '^ID=fedora' /etc/os-release && pass "Base Fedora" || fail "Base Fedora"
grep -q '^VERSION_ID=44' /etc/os-release && pass "Fedora 44" || fail "Fedora 44"

# --- Pacchetti obbligatori ---
for p in \
  libreoffice thunderbird firefox okular tesseract \
  pcsc-lite pcsc-lite-ccid pcsc-tools opensc \
  firewalld cups keepassxc usbguard; do
  rpm -q "$p" >/dev/null 2>&1 && pass "pkg:$p" || fail "pkg:$p"
done

# --- File di configurazione ---
for f in /etc/locale.conf /etc/vconsole.conf /etc/skel/README-PA.txt; do
  [ -e "$f" ] && pass "file:$f" || fail "file:$f"
done

# --- Servizi ---
for s in firewalld.service cups.service; do
  [ -e "/etc/systemd/system/multi-user.target.wants/$s" ] \
    && pass "svc:$s abilitato" \
    || fail "svc:$s abilitato"
done
[ -e /etc/systemd/system/multi-user.target.wants/sshd.service ] \
  && fail "svc:sshd disabilitato" \
  || pass "svc:sshd disabilitato"

# --- Sicurezza ---
grep -q '^SELINUX=enforcing' /etc/selinux/config 2>/dev/null \
  && pass "SELinux enforcing" || fail "SELinux enforcing"
command -v pcscd >/dev/null 2>&1 \
  && pass "pcscd presente" || fail "pcscd presente"

# --- Informativi (non bloccanti) ---
for p in sssd realmd appimagelauncher; do
  rpm -q "$p" >/dev/null 2>&1 \
    && info "opzionale presente: $p" \
    || info "opzionale assente: $p"
done

if [ -d /usr/share/plasma/look-and-feel ]; then
  info "look-and-feel: $(ls /usr/share/plasma/look-and-feel/ | tr '\n' ' ')"
else
  info "look-and-feel assente"
fi

[ -e /usr/lib/libcie-pkcs11.so ] \
  && info "CIE middleware presente" \
  || info "CIE middleware assente"

rpm -q desktop-file-utils >/dev/null 2>&1 \
  && info "AppImage: desktop-file-utils presente" \
  || info "AppImage: desktop-file-utils assente"
EOS
)

echo "$report" | while IFS='|' read -r st msg; do
  case "$st" in
    PASS) printf '✅ %s\n' "$msg" ;;
    FAIL) printf '❌ %s\n' "$msg" ;;
    INFO) printf 'ℹ️  %s\n' "$msg" ;;
  esac
done

PASS=$(printf '%s\n' "$report" | grep -c '^PASS|' || true)
FAIL=$(printf '%s\n' "$report" | grep -c '^FAIL|' || true)
INFO=$(printf '%s\n' "$report" | grep -c '^INFO|' || true)

echo
echo "──────────────────────────────────────"
printf 'Pass: %s   Fail: %s   Info: %s\n' "$PASS" "$FAIL" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  echo "Esito: ❌ controlli bloccanti falliti"
  exit 1
fi
echo "Esito: ✅ tutti i controlli bloccanti passano"
