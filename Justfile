# Justfile — PA Desktop (variante Aurora-style)
#
# Prerequisiti: podman (rootless va bene), just.
#   sudo apt-get install -y podman just
#
# Stadio A (immagine):
#   just build   -> OCI image pa-desktop-aurora:latest
#   just lint    -> bootc container lint
#   just push    -> push su registry (se REGISTRY è impostato)
#
# Stadio B (disco/ISO):
#   just disk-image -> qcow2 (QEMU)
#   just iso        -> ISO installer (USB/hardware)
#
# Le operazioni pesanti sono serializzate da un lock flock (default .build.lock):
#   LOCK_WAIT=600 just disk-image   # aspetta invece di fallire subito
#   LOCK_FILE=/tmp/pa.lock just build
set shell := ["bash", "-uc"]

image_name := env("IMAGE_NAME", "pa-desktop-aurora")
image_tag  := env("IMAGE_TAG", "latest")
local_image := image_name + ":" + image_tag
registry   := env("REGISTRY", "")
bib_image  := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

# Registry locale usato da bootc-image-builder
registry_container := env("REGISTRY_NAME", "pa-registry")
registry_port      := env("REGISTRY_PORT", "5005")
registry_ref       := "localhost:" + registry_port + "/" + image_name + ":" + image_tag

lock_file := env("LOCK_FILE", ".build.lock")

default:
    @just --list

# Verifica podman, driver di storage, registry e lock
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0

    if ! command -v podman >/dev/null 2>&1; then
      echo "✗ podman non installato"; exit 1
    fi
    echo "✓ podman: $(podman --version)"

    if ! podman info >/dev/null 2>&1; then
      echo "✗ podman non raggiungibile"
      echo "  rootless: controlla /etc/subuid e /etc/subgid"
      exit 1
    fi
    driver=$(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null)
    echo "✓ podman attivo — graph driver: ${driver:-?}"
    if [ "$driver" = "btrfs" ]; then
      echo "⚠ graph driver 'btrfs' (deprecato): usa overlay, vedi README"
      rc=1
    fi

    if podman unshare true >/dev/null 2>&1; then
      echo "✓ rootless ok (userns)"
    else
      echo "⚠ podman unshare fallito: controlla /etc/subuid e /etc/subgid"
      rc=1
    fi

    if podman container inspect "{{registry_container}}" >/dev/null 2>&1; then
      echo "• registry {{registry_container}} presente (127.0.0.1:{{registry_port}})"
    else
      echo "• registry {{registry_container}} non creato (lo crea disk-image/iso)"
    fi

    if [ -e "{{lock_file}}" ] && ! flock -n "{{lock_file}}" true 2>/dev/null; then
      echo "⚠ lock occupato: {{lock_file}} (altra build in corso)"
    else
      echo "✓ lock libero: {{lock_file}}"
    fi

    if podman image inspect "{{local_image}}" >/dev/null 2>&1; then
      echo "✓ immagine presente: {{local_image}}"
    else
      echo "• immagine assente: esegui 'just build'"
    fi

    exit $rc

# Prepara l'host (Parrot/Debian, installazione via apt)
setup-host:
    sudo apt-get update && sudo apt-get install -y podman just qemu-system-x86

# Build dell'immagine OCI
build:
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: un'altra operazione PA è in corso (lock {{lock_file}})." >&2
      echo "Attendi la fine oppure usa LOCK_WAIT=600 just build." >&2
      exit 1
    fi
    podman info >/dev/null 2>&1 || { echo "podman non raggiungibile" >&2; exit 1; }
    podman build --pull \
      --file Containerfile.in \
      --tag "{{local_image}}" \
      --build-arg IMAGE_NAME="{{image_name}}" \
      --build-arg VERSION=dev \
      --build-arg SHA_HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo deadbeef)" \
      .

# Validazione bootc
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    podman image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    podman run --rm "{{local_image}}" bootc container lint --fatal-warnings --no-truncate

# Push su registry (richiede REGISTRY, es. ghcr.io/OWNER)
push:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{registry}}" ]; then
      echo "REGISTRY non impostato (es. REGISTRY=ghcr.io/tuo-utente just push)"; exit 1
    fi
    podman tag "{{local_image}}" "{{registry}}/{{image_name}}:{{image_tag}}"
    # ~260 layer: ghcr.io può rispondere 429. I blob già caricati vengono saltati,
    # quindi ritentare riprende da dove si era fermato.
    for i in 1 2 3 4 5; do
      podman push "{{registry}}/{{image_name}}:{{image_tag}}" && exit 0
      [ "$i" -eq 5 ] && break
      echo "push fallito (tentativo $i/5), riprovo tra $((i * 30))s" >&2
      sleep $((i * 30))
    done
    echo "push fallito dopo 5 tentativi" >&2
    exit 1

# Verifica firma del kernel (best effort: richiede sbsigntools)
secureboot:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v sbverify >/dev/null 2>&1; then
      echo "sbverify non trovato (sbsigntools): salto il controllo"; exit 0
    fi
    TMP=$(mktemp -d)
    CID=$(podman create "{{local_image}}")
    podman cp "$CID":/usr/lib/modules "$TMP/modules" 2>/dev/null || true
    podman rm "$CID" >/dev/null
    VMLINUZ=$(find "$TMP/modules" -name vmlinuz | head -1 || true)
    if [ -z "$VMLINUZ" ]; then echo "vmlinuz non trovato: salto"; rm -rf "$TMP"; exit 0; fi
    sbverify --list "$VMLINUZ"
    rm -rf "$TMP"

# Avvia (o crea) il registry locale per bootc-image-builder
registry-up:
    #!/usr/bin/env bash
    set -euo pipefail
    podman info >/dev/null 2>&1 || { echo "podman non raggiungibile" >&2; exit 1; }
    if podman container inspect "{{registry_container}}" >/dev/null 2>&1; then
      podman start "{{registry_container}}" >/dev/null 2>&1 || true
    else
      podman run -d --name "{{registry_container}}" \
        --restart unless-stopped \
        -p "127.0.0.1:{{registry_port}}:5000" \
        docker.io/library/registry:2 >/dev/null || true
    fi
    for _ in $(seq 1 30); do
      if curl -fsS "http://127.0.0.1:{{registry_port}}/v2/" >/dev/null 2>&1; then
        echo "registry pronto: 127.0.0.1:{{registry_port}}"
        exit 0
      fi
      sleep 1
    done
    echo "ERRORE: registry non raggiungibile su 127.0.0.1:{{registry_port}}" >&2
    exit 1

# Ferma e rimuove il registry locale
registry-down:
    -podman stop {{registry_container}}
    -podman rm {{registry_container}}

# Stadio B: qcow2 per QEMU
disk-image: registry-up
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: un'altra operazione PA è in corso (lock {{lock_file}})." >&2
      exit 1
    fi
    podman image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    podman tag "{{local_image}}" "{{registry_ref}}"
    # podman (Debian/Parrot) non fa fallback https->http per localhost: serve
    # --tls-verify=false per il registry locale non cifrato
    # NB: non si applica al push verso registry remoti (riceve TLS vero)
    podman push --tls-verify=false "{{registry_ref}}"
    mkdir -p output
    # bib richiede (1) podman rootful (validazione interna, come l'azione CI che
    # fa "sudo podman pull") e (2) lo storage rootful montato nel container.
    sudo podman pull --tls-verify=false "{{registry_ref}}"
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --security-opt label=disable \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      -v "{{justfile_directory()}}/registry-localhost.conf:/etc/containers/registries.conf.d/localhost.conf:ro" \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      --type qcow2 --config /config/disk.toml "{{registry_ref}}"
    sudo chown -R "$(id -u):$(id -g)" output || true
    echo "→ output/qcow2/disk.qcow2"

# Stadio B: ISO installer (USB / hardware)
iso: registry-up
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: un'altra operazione PA è in corso (lock {{lock_file}})." >&2
      exit 1
    fi
    podman image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    podman tag "{{local_image}}" "{{registry_ref}}"
    podman push --tls-verify=false "{{registry_ref}}"
    mkdir -p output
    # bib richiede (1) podman rootful (validazione interna, come l'azione CI che
    # fa "sudo podman pull") e (2) lo storage rootful montato nel container.
    sudo podman pull --tls-verify=false "{{registry_ref}}"
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --security-opt label=disable \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      -v "{{justfile_directory()}}/registry-localhost.conf:/etc/containers/registries.conf.d/localhost.conf:ro" \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      --type anaconda-iso --config /config/iso.toml "{{registry_ref}}"
    sudo chown -R "$(id -u):$(id -g)" output || true
    echo "→ output/iso/*.iso"

# Pulizia (immagine locale + output)
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: un'altra operazione PA è in corso (lock {{lock_file}})." >&2
      exit 1
    fi
    rm -rf output
    podman rmi "{{local_image}}" >/dev/null 2>&1 || true
    podman rmi "{{registry_ref}}" >/dev/null 2>&1 || true
