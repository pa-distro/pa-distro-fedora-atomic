PA Desktop — contenuti di branding e file di sistema.

Questa cartella viene copiata nella radice dell'immagine da
build_scripts/base/03-files.sh: system_files/*  ->  /

Cosa mettere qui:
  etc/locale.conf          locale italiana (già presente)
  etc/vconsole.conf        tastiera italiana (già presente)
  etc/skel/*               file copiati nella home dei nuovi utenti
  etc/profile.d/*          prompt bash PA
  etc/sssd/sssd.conf       config AD/LDAP (se attivato in 01-packages.sh)
  usr/share/pa/*           risorse del progetto (logo, guida)
  usr/share/plasma/...     Look-and-Feel org.pa.desktop (tema PA)
  usr/share/color-schemes/ palette PADark
  usr/share/aurorae/       decorazioni Sweet-Mars (GPL-3)
  usr/share/icons/         icone Flat-Remix-Green-Dark (GPL-3)
  usr/share/konsole/       profilo e colori PA
  usr/share/wallpapers/    KPackage wallpaper PA
  usr/share/kde-settings/  default KDE/Konsole/lock screen/preferiti

Licenze e provenienza: vedi LICENSES/ e SOURCES.md nella radice del repo.

ATTENZIONE: NON copiare file in /home, /opt, /srv, /root, /usr/local, /mnt, /tmp
(rpm-ostree li collega a /var e andrebbero in conflitto).
