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

# Always re-own the tree on exit, even on failure, so the user isn't left with
# a root-owned git checkout.
trap 'restore_ownership' EXIT

MODE_LABEL="dev"; [ "${RELEASE}" = "1" ] && MODE_LABEL="release"
log "BETRIEBSSYSTEM ${BS_VERSION} -- ${MODE_LABEL} build"
log "distribution=${BS_DISTRIBUTION:-trixie} arch=${BS_ARCH:-amd64}"

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
lb clean noauto >/dev/null 2>&1 || true

# 5. configure (runs auto/config) then build
log "lb config"
lb config

log "lb build  (this downloads packages and can take 20-60+ minutes)"
set +e
lb build 2>&1 | tee build.log
RC="${PIPESTATUS[0]}"
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
