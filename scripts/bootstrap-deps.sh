#!/usr/bin/env bash
# Install the host packages needed to build a BETRIEBSSYSTEM ISO.
# Run as root (build.sh calls this automatically).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_root "$@"

DEPS=(
    live-build          # the build engine
    debootstrap         # bootstraps the Debian chroot
    squashfs-tools      # mksquashfs -> the live filesystem image
    xorriso             # authors the hybrid ISO
    mtools dosfstools   # FAT EFI system partition image
    grub-pc-bin         # BIOS GRUB modules
    grub-efi-amd64-bin  # UEFI GRUB modules
    grub-common
    python3-pil         # branding asset generation
    ca-certificates
    rsync
)

log "ensuring build dependencies are installed"
export DEBIAN_FRONTEND=noninteractive
MISSING=()
for p in "${DEPS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
done

if [ "${#MISSING[@]}" -eq 0 ]; then
    log "all build dependencies already present"
else
    log "installing: ${MISSING[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${MISSING[@]}"
fi
