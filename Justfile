export image_name := env("IMAGE_NAME", "ludos") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo and System Resources
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    
    echo "🧹 Starting comprehensive cleanup..."
    
    # Clean LudOS build artifacts
    echo "Cleaning LudOS build artifacts..."
    touch _build
    find . -name "*_build*" -type d -exec rm -rf {} + 2>/dev/null || true
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/
    
    # Clean troubleshooting files
    echo "Cleaning troubleshooting files..."
    rm -rf troubleshooting/logs/* 2>/dev/null || true
    rm -rf troubleshooting/screenshots/* 2>/dev/null || true
    rm -rf troubleshooting/dumps/* 2>/dev/null || true
    
    # Clean NVIDIA build artifacts
    echo "Cleaning NVIDIA build artifacts..."
    rm -rf nvidia-kmod/build/* 2>/dev/null || true
    rm -f nvidia-kmod/*.run 2>/dev/null || true
    rm -f nvidia-kmod/*.rpm 2>/dev/null || true
    rm -f nvidia-kmod/*.tar.xz 2>/dev/null || true
    
    # Clean container storage (most important for disk space)
    echo "Cleaning container storage..."
    podman system prune -a -f --volumes 2>/dev/null || true
    buildah rm --all 2>/dev/null || true
    podman image prune -a -f 2>/dev/null || true
    
    # Clean system package cache
    echo "Cleaning system package cache..."
    sudo dnf clean all 2>/dev/null || true
    
    # Clean journal logs (keep last 3 days)
    echo "Cleaning journal logs..."
    sudo journalctl --vacuum-time=3d 2>/dev/null || true
    
    # Clean temporary files
    echo "Cleaning temporary files..."
    rm -rf /tmp/_build* 2>/dev/null || true
    rm -rf /tmp/tmp.* 2>/dev/null || true
    
    # Show disk usage after cleanup
    echo "🎉 Cleanup complete!"
    echo "Current disk usage:"
    df -h / | grep -E "(Filesystem|/dev/)"

# Aggressive cleanup for low disk space situations
[group('Utility')]
deep-clean:
    #!/usr/bin/bash
    set -eoux pipefail
    echo "Disk usage before deep-clean extras:"
    df -h /

    # Clean RPM ostree cache and old deployments
    echo "Cleaning rpm-ostree cache and old deployments..."
    sudo rpm-ostree cleanup -m 2>/dev/null || true
    sudo rpm-ostree cleanup -prune --base 1 2>/dev/null || true

    if command -v ostree >/dev/null 2>&1; then
    echo "Pruning detached ostree refs and temp directories..."
    sudo ostree refs --repo=/ostree/repo 2>/dev/null | grep '^ostree/1/' | xargs -r sudo ostree refs --repo=/ostree/repo --delete 2>/dev/null || true
    sudo ostree cleanup --repo=/ostree/repo 2>/dev/null || true
    sudo find /ostree/repo/tmp -mindepth 1 -maxdepth 1 -type d -mtime +1 -print -exec sudo rm -rf {} + 2>/dev/null || true
    fi

    if command -v bootc >/dev/null 2>&1; then
    echo "Cleaning old bootc checkpoints..."
    sudo bootc status checkpoints 2>/dev/null | awk 'NR>2 {print $1}' | tail -n +2 | xargs -r sudo bootc delete checkpoint 2>/dev/null || true
    fi

    # Clean all container images (not just unused ones)
    echo "Removing ALL container images..."
    podman rmi -a -f 2>/dev/null || true
    buildah rmi -a -f 2>/dev/null || true
    podman volume prune -f 2>/dev/null || true
    podman system prune -a -f --volumes 2>/dev/null || true
    podman system reset -f 2>/dev/null || true

    echo "Removing lingering container storage directories..."
    rm -rf ~/.local/share/containers 2>/dev/null || true
    sudo rm -rf /var/lib/containers 2>/dev/null || true
    sudo rm -rf /var/tmp/containers 2>/dev/null || true

    # Clean more system caches
    echo "Cleaning additional system caches..."
    sudo dnf clean all 2>/dev/null || true
    rm -rf ~/.cache/* 2>/dev/null || true
    sudo rm -rf /var/cache/dnf/* 2>/dev/null || true
    sudo rm -rf /var/cache/PackageKit/* 2>/dev/null || true
    sudo rm -rf /var/cache/rpm-ostree/* 2>/dev/null || true
    sudo rm -rf /var/cache/fwupd/* 2>/dev/null || true

    # Clean journal logs more aggressively (keep last 1 day)
    echo "Cleaning journal logs (keep 1 day)..."
    sudo journalctl --vacuum-time=1d 2>/dev/null || true
    sudo journalctl --vacuum-size=100M 2>/dev/null || true

    # Clean coredumps
    echo "Cleaning coredumps..."
    sudo rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
    sudo coredumpctl remove 2>/dev/null || true

    # Clean old kernels (keep current + 1)
    echo "Cleaning old kernels..."
    sudo dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q) -y 2>/dev/null || true

    echo "Truncating RPM/DNF logs..."
    sudo sh -c 'for f in /var/log/dnf* /var/log/rpm*; do [ -f "$f" ] && : > "$f"; done' 2>/dev/null || true
    sudo rm -f /var/lib/rpm/__db.* 2>/dev/null || true

    # Clean user temp files
    echo "Cleaning user temporary files..."
    rm -rf ~/.local/share/Trash/* 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true

    echo "Disk usage after deep-clean extras:"
    df -h /

# Check disk space and warn if low
[group('Utility')]
check-space:
    #!/usr/bin/bash
    set -euo pipefail
    
    echo "💾 Checking disk space..."
    df -h / | grep -E "(Filesystem|/dev/)"
    
    # Get usage percentage (remove % sign)
    usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt 85 ]; then
        echo "⚠️  WARNING: Disk usage is ${usage}% - consider running 'just clean'"
        echo "   Container builds need 15-20GB free space"
        if [ "$usage" -gt 90 ]; then
            echo "❌ ERROR: Disk usage too high (${usage}%) - build will likely fail"
            echo "   Run 'just clean' before building"
            exit 1
        fi
    else
        echo "✅ Disk space OK (${usage}% used)"
    fi

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build aurora lts
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build the image using the specified parameters
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    # Handle file operations with proper sudo session management
    echo "Moving build output files..."
    while ! sudo mv -f $BUILDTMP/* output/ 2>/dev/null; do
        echo "Please enter your sudo password to complete the build:"
        sudo -v
    done
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/
    
    # Rename ISO file with version and build metadata
    if [[ $type == iso ]] && [[ -f output/bootiso/install.iso ]]; then
        VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
        BUILD_DATE=$(date +%Y%m%d)
        BUILD_TIME=$(date +%H%M)
        GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        
        ISO_NAME="ludos-v${VERSION}-${BUILD_DATE}.${BUILD_TIME}-${GIT_HASH}.iso"
        sudo mv output/bootiso/install.iso output/bootiso/${ISO_NAME}
        echo "Renamed ISO to ${ISO_NAME}"
        echo "Version: ${VERSION}, Build: ${BUILD_DATE}.${BUILD_TIME}, Commit: ${GIT_HASH}"
    fi

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Version management recipes
version:
    @echo "Current version: $(cat VERSION 2>/dev/null || echo '1.0.0')"

# Bump version (patch, minor, or major)
bump-version type:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(cat VERSION 2>/dev/null || echo "1.0.0")
    IFS='.' read -r major minor patch <<< "$current"
    
    case "{{type}}" in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            echo "Usage: just bump-version [patch|minor|major]"
            exit 1
            ;;
    esac
    
    new_version="${major}.${minor}.${patch}"
    echo "$new_version" > VERSION
    echo "Version bumped from $current to $new_version"

# Set specific version
set-version version:
    echo "{{version}}" > VERSION
    @echo "Version set to {{version}}"

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: check-space && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/ludos-$(date +%Y%m%d).iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}


# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
