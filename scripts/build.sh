#!/usr/bin/env bash
#
# build.sh -- build a BETRIEBSSYSTEM ISO from scratch.
#
# MUST run as root (live-build bootstraps a chroot, mounts pseudo-filesystems,
# installs packages and builds squashfs).
#
#   sudo ./scripts/build.sh            # dev build
#   sudo RELEASE=1 ./scripts/build.sh  # release build (scrubs build tells)
#
# Output: dist/BETRIEBSSYSTEM-<version>[-release]-amd64.iso
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_root "$@"

RELEASE="${RELEASE:-0}"
cd "${BS_ROOT}"

# Persistent pip cache: a host-side wheel cache that gets bind-mounted into the
# chroot for the chroot stage (where the AI venv / pipx hooks run), so they don't
# re-download multiple GB on every clean build.
PIP_CACHE="${BS_ROOT}/cache/pip"
CHROOT_PIP="${BS_ROOT}/chroot/root/.cache/pip"
cleanup_mounts() {
    if mountpoint -q "${CHROOT_PIP}" 2>/dev/null; then
        umount "${CHROOT_PIP}" 2>/dev/null || umount -l "${CHROOT_PIP}" 2>/dev/null || true
    fi
}

# Always unmount the pip cache and re-own the tree on exit. The unmount is
# safety-critical: a leftover bind mount would let a later `rm -rf chroot/`
# (lb clean) recurse THROUGH it and delete the host cache.
trap 'cleanup_mounts; restore_ownership' EXIT

MODE_LABEL="dev"; [ "${RELEASE}" = "1" ] && MODE_LABEL="release"
log "BETRIEBSSYSTEM ${BS_VERSION} -- ${MODE_LABEL} build"
log "distribution=${BS_DISTRIBUTION:-trixie} arch=${BS_ARCH:-amd64}"

# 0. pre-flight: fail fast on a mistyped/removed package name
"${BS_ROOT}/scripts/verify-packages.sh"

# 1. host build dependencies
"${BS_ROOT}/scripts/bootstrap-deps.sh"

# 2. regenerate branding assets (uses system python3-pil)
log "regenerating branding assets"
python3 "${BS_ROOT}/branding/generate.py"

# 3. write the build-mode marker that the release-scrub chroot hook reads
mkdir -p "${BS_ROOT}/config/includes.chroot/etc"
if [ "${RELEASE}" = "1" ]; then
    echo "release" > "${BS_ROOT}/config/includes.chroot/etc/.bs-buildmode"
else
    echo "dev"     > "${BS_ROOT}/config/includes.chroot/etc/.bs-buildmode"
fi

# 4. clean previous build artifacts (keeps the package cache)
log "lb clean"
cleanup_mounts  # never let lb clean's rm -rf recurse through a stale bind mount
mountpoint -q "${CHROOT_PIP}" 2>/dev/null && die "stale pip-cache mount at ${CHROOT_PIP}; unmount it first"
lb clean noauto >/dev/null 2>&1 || true

# 5. configure (runs auto/config) then build
log "lb config"
lb config

# Stamp all filesystem timestamps to 2002-06-01 00:00 UTC (a fixed, "polished"
# date) instead of random build times. SOURCE_DATE_EPOCH alone does it:
# mksquashfs CLAMPS every file time to be no later than this epoch, and since all
# chroot files are dated "now" (newer), they all collapse to 2002-06-01. It also
# stamps the ISO9660 metadata. (Do NOT also pass mksquashfs -all-time/-mkfs-time:
# mksquashfs refuses both at once.) Calamares preserves these on install.
export SOURCE_DATE_EPOCH=1022889600
log "filesystem timestamps pinned to 2002-06-01 (SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH})"

# Staged build (= lb build) so we can bind the persistent pip cache into the
# chroot for the chroot stage only, and unmount it BEFORE lb binary copies the
# chroot into the image.
log "lb build  (staged: bootstrap -> chroot[+pip cache] -> binary)"
mkdir -p "${PIP_CACHE}"
set +e
{
    lb bootstrap &&
    { mkdir -p "${CHROOT_PIP}" && mount --bind "${PIP_CACHE}" "${CHROOT_PIP}"; } &&
    lb chroot
} 2>&1 | tee build.log
RC="${PIPESTATUS[0]}"
cleanup_mounts  # MUST happen before lb binary copies the chroot
if [ "${RC}" -eq 0 ]; then
    lb binary 2>&1 | tee -a build.log
    RC="${PIPESTATUS[0]}"
fi
set -e
[ "${RC}" -eq 0 ] || die "lb build failed (rc=${RC}); see build.log"

# 6. collect the ISO into dist/
SRC_ISO="$(ls -1 live-image-*.hybrid.iso 2>/dev/null | head -n1 || true)"
[ -n "${SRC_ISO}" ] || die "no ISO produced (expected live-image-*.hybrid.iso)"

mkdir -p "${BS_ROOT}/dist"
SUFFIX=""; [ "${RELEASE}" = "1" ] && SUFFIX="-release"
OUT="${BS_ROOT}/dist/BETRIEBSSYSTEM-${BS_VERSION}${SUFFIX}-amd64.iso"
mv -f "${SRC_ISO}" "${OUT}"
( cd "${BS_ROOT}/dist" && sha256sum "$(basename "${OUT}")" > "$(basename "${OUT}").sha256" )

log "ISO ready: ${OUT}"
log "size: $(du -h "${OUT}" | cut -f1)"

# Archive a hash-stamped copy + manifest row (before lb clean wipes binary/, so
# archive-iso.sh can still read the kernel version from the build tree).
"${BS_ROOT}/scripts/archive-iso.sh" "${OUT}" || warn "archiving failed (non-fatal)"

log "boot it:  ./scripts/run-qemu.sh ${OUT}"
