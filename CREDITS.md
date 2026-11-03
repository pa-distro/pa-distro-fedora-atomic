# Crediti e provenienza

Questo progetto è distribuito con licenza **GPL-3.0-or-later** (vedi `LICENSE`).
Alcuni file di configurazione e asset sono **adattati** da Parrot OS e da progetti terzi.
Qui sotto trovi la provenienza, la versione di riferimento e la licenza.

## Configurazioni e asset adattati

| Componente | Upstream | Versione / data | Licenza | File usati |
|---|---|---|---|---|
| **Parrot `parrot-core`** | https://github.com/ParrotSec/parrot-core | 7.5.0 (2026-11-02) | GPL-3.0-or-later | `system_configs/etc/xdg/*`, `skel/.config/dolphinrc`, `skel/.config/konsolerc` |
| **Parrot `parrot-interface`** | https://github.com/ParrotSec/parrot-interface | 7.4.3 | GPL-3.0-or-later; `browser/00parrot.js` include parti **MIT** (pyllyukko) | `browser/policies.json`, `browser/00parrot.js` |
| **Parrot `parrot-firefox-profiles`** | pacchetto costruito da `parrot-interface` | 7.4.3 | GPL-3.0-or-later | profili/pref Firefox |
| **Parrot `echo-themes`** | https://gitlab.com/parrotsec/packages/echo-themes | 1.3+parrot2 | GPL-3.0-or-later | asset del tema, splash, Konsole |
| **Sweet** (decorazioni Aurorae) | https://github.com/EliverLara/Sweet | — | GPL-3.0 | `Sweet-Mars` |
| **Flat-Remix** (icone) | https://github.com/daniruiz/flat-remix | — | GPL-3.0 | `Flat-Remix-Green-Dark` |
| **pyllyukko user.js** | https://github.com/pyllyukko/user.js | — | MIT | prefs Firefox (via Parrot) |
| **Parrot `parrot-iso-build`** | https://github.com/ParrotSec/parrot-iso-build | — | nessuna licenza dichiarata | **solo riferimento** per le package-list (non copiato) |

## Estensioni Firefox (installate da AMO)

| Estensione | ID | Sorgente | Licenza |
|---|---|---|---|
| **uBlock Origin** | `uBlock0@raymondhill.net` | https://github.com/gorhill/uBlock | GPL-3.0 |
| **NoScript** | `{73a6fe31-595d-460b-a920-fcc0f8843232}` | https://github.com/hackademix/noscript | GPL-3.0 |

> Le estensioni **non vengono ridistribuite** nell'immagine: vengono installate da `addons.mozilla.org` al primo avvio tramite `policies.json`. Le licenze sono riportate per attribuzione.

## Adattamenti e scelte

- I file Parrot sono stati **portati su Fedora/Kinoite**, cambiando i path (es. `/etc/xdg`, `/etc/firefox/policies/policies.json`, `/etc/firefox/pref/00-pa.js`).
- **Esclusi di proposito**: proxy Tor/AnonSurf, `privacy.firstparty.isolate`, `privacy.resistFingerprinting`, locale/regione US, bookmark e branding Parrot, Form History Control, FoxyProxy.
- **NoScript è attivo sempre**: su INPS/Poste/PagoPA/SPID le web-app richiedono di autorizzare il sito al primo accesso. È una scelta esplicita del progetto.
- I bookmark sono in `policies.json` (`ManagedBookmarks`) e sono gestiti centralmente.

## Licenza del progetto

Il progetto è distribuito sotto **GPL-3.0-or-later**. I testi delle licenze sono in:

- `LICENSES/GPL-3.0-or-later.txt`
- `LICENSES/MIT.txt`

I copyright originali restano dei rispettivi autori. Le modifiche PA sono indicate nei file e nella storia del repository.
