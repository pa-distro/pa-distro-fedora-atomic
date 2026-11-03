# Justfile — PA Desktop (podman)
#
# Prerequisiti: podman + buildah + just.
#
# Stadio A (immagine):
#   just build        -> localhost/pa-desktop-aurora:latest (rootless)
#   just lint         -> bootc container lint
#   just push         -> push su registry remoto (REGISTRY=...)
#
# Stadio B (disco/ISO):
#   just disk-image   -> registry locale 127.0.0.1:5005 + bib rootful -> qcow2
#   just iso          -> idem -> ISO
#   just disk-image-offline / iso-offline -> copia rootful (save|load), senza registry
#
# Registry locale:
#   just registry-up / registry-down
#   config: registry-localhost.conf (insecure=true per localhost:5005)
set shell := ["bash", "-uc"]

image_name := env("IMAGE_NAME", "pa-desktop-aurora")
image_tag  := env("IMAGE_TAG", "latest")
local_image := "localhost/" + image_name + ":" + image_tag
registry   := env("REGISTRY", "")
bib_image  := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")
lock_file  := env("LOCK_FILE", ".build.lock")

registry_container := env("REGISTRY_NAME", "pa-registry")
registry_port      := env("REGISTRY_PORT", "5005")
registry_ref       := "localhost:" + registry_port + "/" + image_name + ":" + image_tag
registry_conf      := justfile_directory() + "/registry-localhost.conf"

default:
    @just --list

# Stato di podman, storage, registry e spazio
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    command -v podman >/dev/null 2>&1 || { echo "✗ podman non installato"; exit 1; }
    podman info >/dev/null 2>&1 || { echo "✗ podman non funziona"; exit 1; }
    echo "✓ podman $(podman --version | awk '{print $3}')"
    echo "✓ storage: $(podman info | awk '/graphRoot:/{print $2; exit}')"
    echo "✓ conf registry: {{registry_conf}}"
    if podman container inspect "{{registry_container}}" >/dev/null 2>&1; then
      echo "✓ registry {{registry_container}} presente (127.0.0.1:{{registry_port}})"
    else
      echo "• registry {{registry_container}} non creato"
    fi
    echo
    podman system df
    echo
    df -h . | tail -1
    echo
    if podman image exists "{{local_image}}"; then
      echo "✓ immagine presente: {{local_image}}"
    else
      echo "• immagine assente: esegui 'just build'"
    fi

# Build rootless (ciclo veloce)
build:
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: altra operazione in corso (lock {{lock_file}})." >&2
      echo "Usa LOCK_WAIT=600 just build" >&2
      exit 1
    fi
    podman build --pull=newer --file Containerfile.in \
      --tag "{{local_image}}" \
      --build-arg IMAGE_NAME="{{image_name}}" \
      --build-arg VERSION=dev \
      --build-arg SHA_HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo deadbeef)" \
      .

# Build rootful (alternativa offline)
build-rootful:
    #!/usr/bin/env bash
    set -euo pipefail
    exec 9>"{{lock_file}}"
    if ! flock -w "${LOCK_WAIT:-0}" 9; then
      echo "ERRORE: altra operazione in corso (lock {{lock_file}})." >&2
      exit 1
    fi
    sudo podman build --pull=newer --file Containerfile.in \
      --tag "{{local_image}}" \
      --build-arg IMAGE_NAME="{{image_name}}" \
      --build-arg VERSION=dev \
      --build-arg SHA_HEAD_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo deadbeef)" \
      .

# Validazione bootc
lint:
    podman run --rm "{{local_image}}" bootc container lint --fatal-warnings --no-truncate

# Push su registry remoto (richiede REGISTRY, es. ghcr.io/OWNER)
push:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{registry}}" ]; then
      echo "REGISTRY non impostato (es. REGISTRY=ghcr.io/tuo-utente just push)"; exit 1
    fi
    podman tag "{{local_image}}" "{{registry}}/{{image_name}}:{{image_tag}}"
    podman push "{{registry}}/{{image_name}}:{{image_tag}}"

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

# Avvia (o crea) il registry locale per bib
registry-up:
    #!/usr/bin/env bash
    set -euo pipefail
    if podman container inspect "{{registry_container}}" >/dev/null 2>&1; then
      podman start "{{registry_container}}" >/dev/null 2>&1 || true
    else
      podman run -d --name "{{registry_container}}" \
        --restart unless-stopped \
        -p "127.0.0.1:{{registry_port}}:5000" \
        docker.io/library/registry:2 >/dev/null
    fi
    for _ in $(seq 1 30); do
      if curl -fsS "http://127.0.0.1:{{registry_port}}/v2/" >/dev/null 2>&1; then
        echo "registry pronto: 127.0.0.1:{{registry_port}}"; exit 0
      fi
      sleep 1
    done
    echo "ERRORE: registry non raggiungibile su 127.0.0.1:{{registry_port}}" >&2
    exit 1

registry-down:
    -podman rm -f {{registry_container}}

# Push rootless sul registry locale, usando la config del repo
push-local: build
    podman tag "{{local_image}}" "{{registry_ref}}"
    CONTAINERS_REGISTRIES_CONF="{{registry_conf}}" podman push "{{registry_ref}}"

# Copia rootless -> rootful (alternativa senza registry)
ensure-rootful: build
    #!/usr/bin/env bash
    set -euo pipefail
    if sudo podman image exists "{{local_image}}"; then
      echo "✓ immagine già presente nello storage rootful"
      exit 0
    fi
    echo "→ copia rootless → rootful (~8.8 GB)"
    podman save "{{local_image}}" | sudo podman load
    echo "✓ copiata nello storage rootful"

# Stadio B: qcow2 via registry locale (nuovo CLI image-builder)
disk-image: registry-up push-local
    mkdir -p output
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --cgroupns=host \
      -v /run \
      -v /var \
      --security-opt label=disable \
      --entrypoint /usr/bin/image-builder \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      -v "{{registry_conf}}:/etc/containers/registries.conf:ro" \
      "{{bib_image}}" \
      build \
      --blueprint /config/disk.toml \
      --output-dir /output \
      --bootc-ref "{{registry_ref}}" \
      --bootc-pull-container \
      qcow2
    @echo "→ output/*.qcow2"

# Stadio B: ISO via registry locale (nuovo CLI image-builder)
iso: registry-up push-local
    mkdir -p output
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --cgroupns=host \
      -v /run \
      -v /var \
      --security-opt label=disable \
      --entrypoint /usr/bin/image-builder \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      -v "{{registry_conf}}:/etc/containers/registries.conf:ro" \
      "{{bib_image}}" \
      build \
      --blueprint /config/iso.toml \
      --output-dir /output \
      --bootc-ref "{{registry_ref}}" \
      --bootc-pull-container \
      bootc-installer
    @echo "→ output/*.iso"

# Stadio B offline: copia rootful + image-builder sul ref locale
disk-image-offline: ensure-rootful
    mkdir -p output
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --cgroupns=host \
      -v /run \
      -v /var \
      --security-opt label=disable \
      --entrypoint /usr/bin/image-builder \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      build \
      --blueprint /config/disk.toml \
      --output-dir /output \
      --bootc-ref "{{local_image}}" \
      qcow2
    @echo "→ output/*.qcow2"

iso-offline: ensure-rootful
    mkdir -p output
    sudo podman run --rm --privileged --pull=always \
      --network host \
      --cgroupns=host \
      -v /run \
      -v /var \
      --security-opt label=disable \
      --entrypoint /usr/bin/image-builder \
      -v "{{justfile_directory()}}/disk_config:/config:ro" \
      -v "{{justfile_directory()}}/output:/output" \
      "{{bib_image}}" \
      build \
      --blueprint /config/iso.toml \
      --output-dir /output \
      --bootc-ref "{{local_image}}" \
      bootc-installer
    @echo "→ output/*.iso"

# Recupera spazio: registry, cache build, immagini non usate, output
prune:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "Prima:"; podman system df || true
    podman rm -f "{{registry_container}}" >/dev/null 2>&1 || true
    podman system prune -a --volumes -f || true
    buildah prune -a -f || true
    sudo podman system prune -a --volumes -f || true
    rm -rf output
    echo; echo "Dopo:"; podman system df || true

# Pulizia immagine locale + registry (+ volume) + output + rootful
clean: clean-registry clean-output clean-rootful

# Rimuove solo l'output (qcow2/ISO)
clean-output:
    rm -rf output
    @echo "output/ rimosso"

# Rimuove la copia rootful (immagine + dangling)
clean-rootful:
    -sudo podman rmi "{{local_image}}"
    -sudo podman image prune -f
    @echo "rootful: immagine/dangling rimossi"

# Ferma il registry e rimuove container + volume (perde l'immagine pushata)
clean-registry:
    -podman rm -f -v {{registry_container}}
    @echo "registry: container e volume rimossi"

# Rimuove layer/immagini dangling (rootless + rootful + cache buildah)
clean-dangling:
    podman image prune -f
    buildah prune -a -f
    sudo podman image prune -f
    @echo "dangling: puliti"

# Elenca i volumi rootful non registrati (orfani)
orphan-volumes:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Volume rootful non registrati:"
    comm -23 \
      <(ls -1 /var/lib/containers/storage/volumes 2>/dev/null | sort) \
      <(sudo podman volume ls -q 2>/dev/null | sort) || true
    echo
    echo "Rimuovi con: CONFIRM=1 just clean-orphan-volumes"

# Rimuove i volumi rootful orfani (richiede CONFIRM=1)
clean-orphan-volumes:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "${CONFIRM:-}" != "1" ]; then
      echo "Imposta CONFIRM=1 per rimuovere i volumi orfani."
      echo "Prima controlla con: just orphan-volumes"
      exit 1
    fi
    mapfile -t vols < <(
      comm -23 \
        <(ls -1 /var/lib/containers/storage/volumes 2>/dev/null | sort) \
        <(sudo podman volume ls -q 2>/dev/null | sort)
    )
    if [ "${#vols[@]}" -eq 0 ]; then
      echo "Nessun volume orfano."
      exit 0
    fi
    for v in "${vols[@]}"; do
      echo "→ rimuovo $v"
      sudo rm -rf "/var/lib/containers/storage/volumes/$v"
    done
    echo "Fatto."

# Pulizia totale (aggressiva): registry, cache, immagini, rootful, output
clean-all:
    #!/usr/bin/env bash
    set -uo pipefail
    podman rm -f -v "{{registry_container}}" >/dev/null 2>&1 || true
    podman system prune -a --volumes -f || true
    buildah prune -a -f || true
    sudo podman system prune -a --volumes -f || true
    rm -rf output
    echo "Pulizia completa."

# Riepilogo spazio
space:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "== btrfs =="; df -h . | tail -1
    btrfs filesystem usage -T / 2>/dev/null | grep -E "Device allocated|Used:|Free \(estimated\)|Free \(statfs" || true
    echo; echo "== rootless =="; podman system df || true
    echo; echo "== rootful =="; sudo podman system df || true
    echo; echo "== directory =="
    du -sh "$HOME/.local/share/containers" 2>/dev/null || true
    sudo du -sh /var/lib/containers/storage 2>/dev/null || true
    du -sh output 2>/dev/null || true
    echo; echo "== qcow2 =="; du -sh output/*.qcow2 2>/dev/null || true
