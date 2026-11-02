# PA Desktop — variante "Aurora-style" (Containerfile + Justfile)

> [!IMPORTANT]
> **Scopo: confronto.** Questa cartella è una **reimplementazione snella** del pattern di build di Aurora/Universal Blue, affiancata a `../pa-distro/` (che usa **BlueBuild**).
> **Non** è un fork di `ublue-os/aurora`: niente `common`/`brew`/`akmods`/`chunkah`, solo i due stadi essenziali.
> **Desktop:** Plasma 6 con identità **PA** derivata dal ricing ParrotOS 7 "Echo" (tema `org.pa.desktop`).

---

## I due stadi

```text
Containerfile.in + build_scripts/
        │ just build (podman)
        ▼
   OCI image (pa-desktop-aurora:latest)
        │                                  ┌── just disk-image → qcow2 → QEMU
        └──────────────────────────────────┤
                                           └── just iso        → ISO   → USB/hardware
```

| Stadio | Cosa fa | File | Tool |
|---|---|---|---|
| **A — immagine** | costruisce l'OS | `Containerfile.in`, `build_scripts/` | `podman`, `bootc container lint` |
| **B — disco/ISO** | rende l'immagine avviabile | `disk_config/*.toml` | `bootc-image-builder` + registry locale |

> [!NOTE]
> Lo stadio B **non ricompila niente**: prende l'immagine A e la scrive su un disco/ISO. È la stessa separazione che trovi in Aurora/uBlue/Bazzite.

---

## Struttura

```text
pa-distro-aurora/
├── Containerfile.in
├── build_scripts/
│   ├── shared/{build-prep,clean-stage}.sh
│   └── base/{01-packages,02-kernel-akmods,03-files,04-services,05-theme,99-finalize}.sh
├── system_files/                 # copiato in /: tema PA, config KDE, skel, locale
│   ├── etc/                      # locale, vconsole, profile.d, skel
│   └── usr/share/                # plasma, color-schemes, aurorae, icons, konsole,
│                                 # wallpapers, kde-settings, pa/branding
├── assets/branding/              # sorgenti SVG di logo e wallpaper
├── LICENSES/                     # GPL-3, licenze asset, NOTICE
├── SOURCES.md                    # provenienza e commit degli asset
├── Justfile                      # build · lint · push · doctor · disk-image · iso
├── .dockerignore                 # contesto minimo (niente output/, asset, .git)
├── .github/workflows/
│   ├── build-image.yml           # stadio A (build + cosign)
│   └── build-disk.yml            # stadio B (qcow2 + anaconda-iso)
├── disk_config/{disk,iso}.toml
├── cosign.pub.example
└── .gitignore                    # output/, immagini, .build.lock
```

---

## Prerequisiti (host locale: Parrot 7.4 "echo", via apt)

| Strumento | Installazione |
|---|---|
| `podman` | `sudo apt-get install -y podman` (rootless va bene, controlla `/etc/subuid` e `/etc/subgid`) |
| `just` | `sudo apt-get install -y just` (se assente nei repo: `cargo install just` oppure il pacchetto di GitHub releases) |
| `qemu-system-x86` | `sudo apt-get install -y qemu-system-x86` (per provare il qcow2: `/dev/kvm` disponibile → accelerazione hardware) |
| `bootc-image-builder` | immagine `quay.io/centos-bootc/bootc-image-builder` (via podman) |
| `sbsigntools` (opz.) | per `just secureboot` |

> [!TIP]
> `just setup-host` esegue l'installazione con `sudo` (solo Parrot/Debian);
> `just doctor` controlla podman, graph driver, userns e lock.

---

## Uso

```bash
# Controllo ambiente
just doctor         # podman ok? driver? userns? lock libero?

# Stadio A
just build          # podman build -> pa-desktop-aurora:latest
just lint           # bootc container lint
just secureboot     # best effort

# Stadio B (registry locale automatico: 127.0.0.1:5005)
just disk-image     # output/qcow2/disk.qcow2  -> QEMU
just iso            # output/iso/*.iso         -> USB/hardware
just registry-down  # spegne/rimuove il registry locale

# Registry remoto
REGISTRY=ghcr.io/TUO-UTENTE just push
```

> [!WARNING]
> `bootc-image-builder` riceve l'immagine **da un registry**, non dallo storage
> locale. `just disk-image`/`just iso` quindi pubblicano l'immagine su un
> registry locale (`pa-registry`, `127.0.0.1:5005`) e passano a bib il
> riferimento; il container bib gira con `--network host`. Il push verso
> localhost richiede `--tls-verify=false` su podman (Debian/Parrot non
> riconosce localhost come insicuro); bib legge invece la drop-in
> `registries.conf.d` che la ricetta monta nel container. Per **Secure Boot**
> in test: immagini non firmate → SB disattivato o enroll delle chiavi.

---

## Podman, btrfs e lock

**Perché podman.** Non c'è daemon da attivare: podman gira rootless e usa lo
storage di `containers-storage`. Il driver consigliato è `overlay` (default);
il driver `btrfs` nativo è deprecato. Se `just doctor` segnala
`graph driver: btrfs`, imposta in `/etc/containers/storage.conf`:

```toml
[storage]
driver = "overlay"
```

(poi eventualmente `podman system reset` per ricostruire lo storage; le
immagini già presenti spariscono dall'elenco). Nota: su installazioni nuove
podman sceglie comunque overlay, quindi in genere non serve toccare nulla.

**Lock di build.** `build`, `disk-image`, `iso` e `clean` sono serializzati da
`flock` sul file `.build.lock` (in `.gitignore`). Se un'altra operazione è in
corso il comando esce subito con un messaggio; per mettersi in coda:

```bash
LOCK_WAIT=600 just build
LOCK_FILE=/tmp/pa.lock just disk-image   # lock alternativo
```

Serve a evitare due `podman build`/bib in parallelo, che si contenderebbero
storage, tag e registry locale. `just doctor` mostra se il lock è occupato.

**Registry locale.** `just disk-image`/`just iso` creano (se assente) un container
`pa-registry` (`registry:2`) in ascolto solo su `127.0.0.1:5005`. È effimero:
`just registry-down` lo elimina; il nome e la porta si cambiano con
`REGISTRY_NAME`/`REGISTRY_PORT`. L'output di bib è scritto come root: dopo il
build, `sudo chown -R "$USER:$USER" output`.

---

## Confronto con `pa-distro/` (BlueBuild)

| | `pa-distro/` (BlueBuild) | `pa-distro-aurora/` (Containerfile) |
|---|---|---|
| Cosa scrivi | `recipe.yml` + moduli | `Containerfile.in` + script shell |
| Build | `bluebuild build` | `just build` (`podman`) |
| Finalizzazione | gestita dai moduli | `bootc container lint` esplicito |
| Composizione moduli | `from-file` dichiarativo | script numerati |
| ISO | `bluebuild generate-iso` | `build-disk.yml` / `just iso` |
| Controllo | alto | **massimo** |
| Manutenzione | bassa | **alta** |
| Adatto a | prototipo rapido, CI pronta | studio del processo, fork "fedele" |

---

## Branding e tema (Parrot 7 "Echo" → PA)

L'identità desktop è ispirata al ricing di ParrotOS 7, ma con look PA e senza asset Parrot.

| Elemento | Valore |
|---|---|
| Look-and-Feel | `org.pa.desktop` (palette `PADark`, Flat-Remix-Green-Dark, Sweet-Mars) |
| Pannello | in basso, ~44 px, flottante: Kickoff **di default**, 5 pin, tray, orologio, mostra desktop |
| Preferiti Kickoff | Firefox, Thunderbird, Writer, Calc, Impress, Okular, Dolphin, Simple Scan |
| Login screen | **Plasma Login Manager** (`plasmalogin`): wallpaper PA via `/etc/plasmalogin.conf` |
| Lock screen | wallpaper PA, autolock 5 min, lock on resume |
| Terminale | Konsole `PA` (verde su nero) + **zsh** + prompt Parrot + **fastfetch**; **btop** solo CLI |
| Sistema | Baloo off, animazioni rapide, 4 desktop, Alt-Tab compatto, pulsanti finestra a destra |
| Wallpaper/logo | originali PA (`assets/branding/`), licenza CC-BY-SA-4.0 |

Dove vivono i default:

- identità e layout: `system_files/usr/share/plasma/look-and-feel/org.pa.desktop`;
- patch di `/usr/share/kde-settings/kde-profile/default/xdg/{kdeglobals,kwinrc,baloofilerc}`
  e di `/etc/plasmalogin.conf` in `build_scripts/base/05-theme.sh` (offline, dopo `03-files.sh`).
  **Non** in `/etc/xdg`: oscurerebbe i default Fedora;
- `kicker-extra-favoritesrc`, `konsolerc`, `kscreenlockerrc`, `mimeapps.list`: stessi path `kde-settings`;
- prompt bash: `/etc/profile.d/pa-prompt.sh`; prompt zsh: blocco marcato in `/etc/zshrc`.

> [!WARNING]
> **Solo utenti nuovi.** Tema, layout e Preferiti vengono applicati alla prima sessione
> (o alla prima creazione dell'applet). Un profilo già esistente mantiene `~/.config`:
> per riallinearlo: `plasma-apply-lookandfeel org.pa.desktop` + reset layout.

> [!NOTE]
> `fastfetch` parte a ogni shell interattiva. Per disattivarlo: commentare la riga nel
> blocco `# >>> PA Desktop >>>` in `/etc/zshrc` (o usare `~/.zshrc`).
> L'utente creato dall'ISO/Anaconda resta su bash: per zsh serve `user --shell=/bin/zsh`
> nel kickstart; su qcow2 lo imposta `disk_config/disk.toml`.

---

## Note

- Base: `quay.io/fedora-ostree-desktops/kinoite:44`, solo `x86_64` (Plasma 6.7.5).
- Build con **podman** e registry locale per `bootc-image-builder`; niente Docker/buildx, i `RUN --mount` del Containerfile sono gestiti nativamente da buildah.
- Lock di build in `.build.lock` (`flock`), condiviso da `build`, `disk-image`, `iso`, `clean`.
- Login manager: **Plasma Login Manager** (`plasmalogin`), non SDDM; il wallpaper PA è impostato in `/etc/plasmalogin.conf`.
- Pacchetti aggiunti per il tema/terminale: `zsh`, `fastfetch`, `btop`, `source-foundry-hack-fonts`, `gtk-update-icon-cache`.
- Tema, icone e wallpaper aggiungono ~100 MB all'immagine (le icone sono SVG).
- AD/LDAP: decommenta il blocco in `build_scripts/base/01-packages.sh`.
- AppImage: `desktop-file-utils` incluso; `appimagelauncher` va aggiunto via COPR/Flatpak.
- `cosign.pub.example` è un segnaposto: genera la coppia con `cosign generate-key-pair`.
- Le immagini buildate con Docker nel periodo "docker" restano nello storage di
  Docker (~9 GB): `docker rmi pa-desktop-aurora:latest` per liberare spazio.
- **Stadio B bib**: la ricetta lancia `bootc-image-builder` con `sudo podman run`
  (rootful, perché la validazione interna di bib lo richiede) e montando
  `/var/lib/containers/storage` nel container: bib non vede lo storage di
  podman rootless e ha bisogno del pull rootful dell'immagine
  (`sudo podman pull --tls-verify=false`) prima dell'avvio — lo fa da sé la
  action CI (`bootc-image-builder-action`). Il pull locale del registry passa
  da `registry-localhost.conf` (marca `localhost:5005` insicuro). L'output
  nasce root: la ricetta fa `sudo chown` su `output/`.
- **CPU x86-64-v2 (pre-Haswell, es. i5-3340M)**: `bootc-image-builder:latest`
  (dal commit "install image-builder from CS10 RPM", 2026-10-01) richiede
  x86-64-v3 e va in `Fatal glibc error: CPU does not support x86-64-v3`.
  Su CPU v2 pinnare `BIB_IMAGE` a un digest del 18 Jun 2026 (base fedora 42,
  v2-compatible):
  `quay.io/centos-bootc/bootc-image-builder@sha256:afeffdb5a7ab6bb9d0593b5765412c4d821a9492dbaf26bb5a494e27181d2019`.
