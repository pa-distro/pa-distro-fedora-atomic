# Justfile — PA Desktop (variante Aurora-style)
#
# Prerequisiti: docker (daemon attivo) + plugin buildx, just.
#   sudo systemctl enable --now docker
#   sudo pacman -S --needed docker-buildx
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
bib_image  := "quay.io/centos-bootc/bootc-image-builder:latest"

# Registry locale usato da bootc-image-builder (che con docker non può usare --local)
registry_container := env("REGISTRY_NAME", "pa-registry")
registry_port      := env("REGISTRY_PORT", "5005")
registry_ref       := "localhost:" + registry_port + "/" + image_name + ":" + image_tag

lock_file := env("LOCK_FILE", ".build.lock")

default:
    @just --list

# Verifica docker, buildx, storage driver, registry e lock
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0

    if ! command -v docker >/dev/null 2>&1; then
      echo "✗ docker non installato"; exit 1
    fi
    echo "✓ docker: $(docker --version)"

    if ! docker info >/dev/null 2>&1; then
      echo "✗ daemon docker non raggiungibile"
      echo "  sudo systemctl enable --now docker"
      exit 1
    fi
    driver=$(docker info 2>/dev/null | awk -F': ' '/Storage Driver:/{print $2; exit}')
    echo "✓ daemon attivo — storage driver: ${driver:-?}"
    if [ "$driver" = "btrfs" ]; then
      echo "⚠ storage driver 'btrfs' (deprecato): usa overlay2/containerd, vedi README"
      rc=1
    fi

    if docker buildx version >/dev/null 2>&1; then
      echo "✓ buildx: $(docker buildx version | head -1)"
    else
      echo "✗ manca il plugin buildx (obbligatorio: il Containerfile usa RUN --mount)"
      echo "  sudo pacman -S docker-buildx"
      rc=1
    fi

    if id -nG "$USER" | grep -qw docker; then
      echo "✓ utente nel gruppo docker"
    else
      echo "⚠ utente non nel gruppo docker: sudo usermod -aG docker $USER (poi ri-login)"
      rc=1
    fi

    if docker container inspect "{{registry_container}}" >/dev/null 2>&1; then
      echo "✓ registry {{registry_container}} presente (127.0.0.1:{{registry_port}})"
    else
      echo "• registry {{registry_container}} non creato (lo crea disk-image/iso)"
    fi

    if [ -e "{{lock_file}}" ] && ! flock -n "{{lock_file}}" true 2>/dev/null; then
      echo "⚠ lock occupato: {{lock_file}} (altra build in corso)"
    else
      echo "✓ lock libero: {{lock_file}}"
    fi

    if docker image inspect "{{local_image}}" >/dev/null 2>&1; then
      echo "✓ immagine presente: {{local_image}}"
    else
      echo "• immagine assente: esegui 'just build'"
    fi

    exit $rc

# Prepara l'host (solo Arch/CachyOS): daemon docker + plugin buildx
setup-host:
    sudo systemctl enable --now docker
    sudo pacman -S --needed docker-buildx

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
    docker info >/dev/null 2>&1 || { echo "docker non attivo: sudo systemctl enable --now docker" >&2; exit 1; }
    docker buildx version >/dev/null 2>&1 || { echo "manca buildx: sudo pacman -S docker-buildx" >&2; exit 1; }
    docker buildx build --load --pull \
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
    docker image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    docker run --rm "{{local_image}}" bootc container lint --fatal-warnings --no-truncate

# Push su registry (richiede REGISTRY, es. ghcr.io/OWNER)
push:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{registry}}" ]; then
      echo "REGISTRY non impostato (es. REGISTRY=ghcr.io/tuo-utente just push)"; exit 1
    fi
    docker tag "{{local_image}}" "{{registry}}/{{image_name}}:{{image_tag}}"
    docker push "{{registry}}/{{image_name}}:{{image_tag}}"

# Verifica firma del kernel (best effort: richiede sbsigntools)
secureboot:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v sbverify >/dev/null 2>&1; then
      echo "sbverify non trovato (sbsigntools): salto il controllo"; exit 0
    fi
    TMP=$(mktemp -d)
    CID=$(docker create "{{local_image}}")
    docker cp "$CID":/usr/lib/modules "$TMP/modules" 2>/dev/null || true
    docker rm "$CID" >/dev/null
    VMLINUZ=$(find "$TMP/modules" -name vmlinuz | head -1 || true)
    if [ -z "$VMLINUZ" ]; then echo "vmlinuz non trovato: salto"; rm -rf "$TMP"; exit 0; fi
    sbverify --list "$VMLINUZ"
    rm -rf "$TMP"

# Avvia (o crea) il registry locale per bootc-image-builder
registry-up:
    #!/usr/bin/env bash
    set -euo pipefail
    docker info >/dev/null 2>&1 || { echo "docker non attivo: sudo systemctl enable --now docker" >&2; exit 1; }
    if docker container inspect "{{registry_container}}" >/dev/null 2>&1; then
      docker start "{{registry_container}}" >/dev/null 2>&1 || true
    else
      docker run -d --name "{{registry_container}}" \
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
    -docker stop {{registry_container}}
    -docker rm {{registry_container}}

# Stadio B: qcow2 per QEMU
disk-image: registry-up
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: un'altra operazione PA è in corso (lock {{lock_file}})." >&2
      exit 1
    fi
    docker image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    docker tag "{{local_image}}" "{{registry_ref}}"
    docker push "{{registry_ref}}"
    mkdir -p output
    docker run --rm --privileged --pull=always \
      --network host \
      --security-opt label=disable \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      --type qcow2 --config /config/disk.toml "{{registry_ref}}"
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
    docker image inspect "{{local_image}}" >/dev/null 2>&1 || { echo "manca {{local_image}}: esegui 'just build'" >&2; exit 1; }
    docker tag "{{local_image}}" "{{registry_ref}}"
    docker push "{{registry_ref}}"
    mkdir -p output
    docker run --rm --privileged --pull=always \
      --network host \
      --security-opt label=disable \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      --type anaconda-iso --config /config/iso.toml "{{registry_ref}}"
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
    docker rmi "{{local_image}}" >/dev/null 2>&1 || true
    docker rmi "{{registry_ref}}" >/dev/null 2>&1 || true
