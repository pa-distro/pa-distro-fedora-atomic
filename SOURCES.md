# Provenienza degli asset

Asset di terze parti copiati nell'immagine **a mano** (vendorizzati), con commit
pinnato al momento dell'import. Non usare `git clone` senza aggiornare questo file.

| Asset | Sorgente | Commit | Licenza | Destinazione |
|---|---|---|---|---|
| `Sweet-Mars` (decorazioni Aurorae) | https://gitlab.com/parrotsec/packages/echo-themes | `6a26143b75e8410b92ecc404fbb92c93b7fff737` | GPL-3.0 (© 2025 Eliver Lara) | `system_files/usr/share/aurorae/themes/Sweet-Mars/` |
| `Flat-Remix-Green-Dark` (icone) | https://github.com/daniruiz/flat-remix | `e7de6c346da46e008987228f363b0eae6e638637` | GPL-3.0 (© 2025 Daniel Ruiz de Alegría) | `system_files/usr/share/icons/Flat-Remix-Green-Dark/` |
| Valori colore/UX (`Echo.colors`, `kwinrc`, Konsole, bashrc) | https://gitlab.com/parrotsec/packages/parrot-core + `echo-themes` | `0ab464913082b857f30d9b8b56be3cbb63917da3` / `6a26143b75e8410b92ecc404fbb92c93b7fff737` | GPL-3.0 | riscritti come `PADark.colors`, `PA.profile`, `PAGreen.colorscheme`, `pa-prompt.sh` |

## Cosa NON è stato importato (e perché)

- `parrot-wallpapers`, `graphics/`, loghi e `distributor-logo-parrot*`: marchio Parrot, nessuna licenza di ridistribuzione.
- `echo-sddm` (QML) e SDDM: la base Fedora 44 usa **Plasma Login Manager**; il login PA si limita al wallpaper in `/etc/plasmalogin.conf`.
- `kicker-extra-favoritesrc`, `kded6rc`, `parrot-menu`: specifici di Debian/dpkg o con moduli inesistenti su Plasma 6.7.
- Kvantum `Sweet-Mars`, Force Blur, Round-Corners: non attivi in Parrot e non pacchettizzati.

## Asset PA (originali)

| File | Licenza |
|---|---|
| `assets/branding/pa-logo.svg` | CC-BY-SA-4.0 |
| `assets/branding/pa-wallpaper.svg` + PNG generati | CC-BY-SA-4.0 |
| `system_files/usr/share/wallpapers/PA/**` | CC-BY-SA-4.0 |

## Rigenerare gli asset

```bash
rsvg-convert -w 1920 -h 1080 assets/branding/pa-wallpaper.svg \
  -o system_files/usr/share/wallpapers/PA/contents/images/1920x1080.png
rsvg-convert -w 3840 -h 2160 assets/branding/pa-wallpaper.svg \
  -o system_files/usr/share/wallpapers/PA/contents/images/3840x2160.png
rsvg-convert -w 512 -h 512 assets/branding/pa-logo.svg \
  -o system_files/usr/share/pa/branding/pa-wordmark.png
```
