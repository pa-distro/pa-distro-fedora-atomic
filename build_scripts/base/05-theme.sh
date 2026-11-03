#!/usr/bin/env bash
# PA Desktop — identità KDE/Plasma applicata a build time.
# Eseguito dentro il Containerfile dopo 03-files.sh (offline).
# Idempotente: si può rieseguire sulla stessa immagine senza effetti collaterali.
set -euo pipefail

KDE_PROFILE="/usr/share/kde-settings/kde-profile/default/xdg"
WALLPAPER_DIR="/usr/share/wallpapers/PA"
KWRITE="$(command -v kwriteconfig6 || true)"

say() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------------------
# 0. Precondizioni
# ---------------------------------------------------------------------------
say "05-theme: precondizioni"
test -n "$KWRITE"
test -f "$KDE_PROFILE/kdeglobals"
test -f "$KDE_PROFILE/kwinrc"
test -f "$KDE_PROFILE/baloofilerc"
test -f /usr/share/color-schemes/PADark.colors
test -d /usr/share/plasma/look-and-feel/org.pa.desktop
test -d /usr/share/aurorae/themes/Sweet-Mars
test -f /usr/share/konsole/PA.profile
test -f "$WALLPAPER_DIR/contents/images/3840x2160.png"

# ---------------------------------------------------------------------------
# 1. Default KDE di sistema (patch dei file Fedora, non riscrittura)
# ---------------------------------------------------------------------------
say "05-theme: default KDE (kdeglobals/kwinrc/baloofilerc)"

kw() { "$KWRITE" --file "$1" --group "$2" --key "$3" "$4"; }

kw "$KDE_PROFILE/kdeglobals" KDE LookAndFeelPackage org.pa.desktop
kw "$KDE_PROFILE/kdeglobals" KDE AnimationDurationFactor 0.5
kw "$KDE_PROFILE/kdeglobals" KDE SingleClick false
kw "$KDE_PROFILE/kdeglobals" General ColorScheme PADark
kw "$KDE_PROFILE/kdeglobals" General Name PADark
kw "$KDE_PROFILE/kdeglobals" General AccentColor 46,204,113
kw "$KDE_PROFILE/kdeglobals" General accentColorFromWallpaper false
kw "$KDE_PROFILE/kdeglobals" General BrowserApplication org.mozilla.firefox.desktop
kw "$KDE_PROFILE/kdeglobals" Icons Theme Flat-Remix-Green-Dark

kw "$KDE_PROFILE/kwinrc" org.kde.kdecoration2 library org.kde.kwin.aurorae
kw "$KDE_PROFILE/kwinrc" org.kde.kdecoration2 theme __aurorae__svg__Sweet-Mars
kw "$KDE_PROFILE/kwinrc" org.kde.kdecoration2 ButtonsOnRight IAX
kw "$KDE_PROFILE/kwinrc" org.kde.kdecoration2 ButtonsOnLeft ""
kw "$KDE_PROFILE/kwinrc" org.kde.kdecoration2 BorderSizeAuto false
kw "$KDE_PROFILE/kwinrc" Desktops Number 4
kw "$KDE_PROFILE/kwinrc" Desktops Rows 1
kw "$KDE_PROFILE/kwinrc" Windows BorderlessMaximizedWindows false
kw "$KDE_PROFILE/kwinrc" Plugins blurEnabled false
kw "$KDE_PROFILE/kwinrc" Plugins scaleEnabled false
kw "$KDE_PROFILE/kwinrc" Plugins squashEnabled false
kw "$KDE_PROFILE/kwinrc" Plugins wobblywindowsEnabled false
kw "$KDE_PROFILE/kwinrc" TabBox LayoutName compact

kw "$KDE_PROFILE/baloofilerc" "Basic Settings" "Indexing-Enabled" false

# ---------------------------------------------------------------------------
# 2. Plasma Login Manager: stesso wallpaper del desktop
#    PLM legge /etc/plasmalogin.conf (default di distro: /usr/lib/plasmalogin/defaults.conf)
# ---------------------------------------------------------------------------
say "05-theme: Plasma Login Manager"
if [ -f /etc/plasmalogin.conf ] && ! grep -q '# >>> PA Desktop >>>' /etc/plasmalogin.conf; then
    cat >> /etc/plasmalogin.conf <<'EOF'

# >>> PA Desktop >>>
[Greeter]
WallpaperPlugin=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/PA/
PreviewImage=file:///usr/share/wallpapers/PA/
# <<< PA Desktop <<<
EOF
else
    echo "ATTENZIONE: /etc/plasmalogin.conf assente o già patchato" >&2
fi

# ---------------------------------------------------------------------------
# 3. Preferiti Kickoff: gli id devono esistere (altrimenti build rotta)
# ---------------------------------------------------------------------------
say "05-theme: verifica preferiti .desktop"
for id in \
    org.mozilla.firefox.desktop \
    net.thunderbird.Thunderbird.desktop \
    libreoffice-writer.desktop \
    libreoffice-calc.desktop \
    libreoffice-impress.desktop \
    org.kde.okular.desktop \
    org.kde.dolphin.desktop \
    org.gnome.SimpleScan.desktop
do
    if [ ! -f "/usr/share/applications/$id" ]; then
        echo "ERRORE: manca /usr/share/applications/$id (aggiornare kicker-extra-favoritesrc)" >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# 4. Cache icone per app GTK
# ---------------------------------------------------------------------------
say "05-theme: cache icone"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/Flat-Remix-Green-Dark || true
fi

# ---------------------------------------------------------------------------
# 5. zsh: prompt PA, history, completamenti, fastfetch (append idempotente)
# ---------------------------------------------------------------------------
say "05-theme: /etc/zshrc"
if [ -f /etc/zshrc ] && ! grep -q '# >>> PA Desktop >>>' /etc/zshrc; then
    cat >> /etc/zshrc <<'EOF'

# >>> PA Desktop >>>
autoload -Uz compinit && compinit -C
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS
PROMPT=$'%F{red}\u250c\u2500\u2500%f[%F{yellow}%n%f@%F{cyan}%m%f]\u2500[%F{green}%~%f]\n%F{red}\u2514\u2500\u2500\u257c%f %F{yellow}%#%f '
if [[ -o interactive ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
# <<< PA Desktop <<<
EOF
fi

# ---------------------------------------------------------------------------
# 6. Timezone di default dell'immagine
#    (il nuovo image-builder non accetta customizations.timezone per qcow2)
# ---------------------------------------------------------------------------
say "05-theme: timezone"
if [ -f /usr/share/zoneinfo/Europe/Rome ]; then
    ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
else
    echo "ATTENZIONE: /usr/share/zoneinfo/Europe/Rome assente" >&2
fi

# ---------------------------------------------------------------------------
# 7. Nuovi utenti creati da CLI: shell zsh
# ---------------------------------------------------------------------------
say "05-theme: /etc/default/useradd"
if [ -f /etc/default/useradd ]; then
    if grep -q '^SHELL=' /etc/default/useradd; then
        sed -i 's|^SHELL=.*|SHELL=/bin/zsh|' /etc/default/useradd
    else
        printf 'SHELL=/bin/zsh\n' >> /etc/default/useradd
    fi
fi

say "05-theme: completato"
