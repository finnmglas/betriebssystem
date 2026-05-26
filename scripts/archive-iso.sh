#!/usr/bin/env bash
#
# archive-iso.sh -- file a built ISO into archive/ stamped with the git commit
# it was built from, and record it in the tracked archive/MANIFEST.md.
#
#   ./scripts/archive-iso.sh [ISO]
#
# If no ISO is given, the newest dist/*.iso is used. The ISO binary itself is
# git-ignored (too big); the manifest row is committed so any build is
# reproducible: `git checkout <commit>` then `sudo ./scripts/build.sh`.
#
# Uses a hardlink when possible so archiving costs no extra disk.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ISO="${1:-$(ls -1t "${BS_ROOT}"/dist/*.iso 2>/dev/null | head -n1 || true)}"
[ -n "${ISO}" ] && [ -f "${ISO}" ] || die "no ISO to archive (pass a path or build one)"

cd "${BS_ROOT}"
mkdir -p archive

# Provenance. BS_ARCHIVE_COMMIT lets you stamp an ISO with the commit it was
# *actually* built from (e.g. archiving after later edits); default is HEAD.
if [ -n "${BS_ARCHIVE_COMMIT:-}" ]; then
    HASH="$(git rev-parse --short "${BS_ARCHIVE_COMMIT}" 2>/dev/null || echo "${BS_ARCHIVE_COMMIT}")"
    DIRTY=""
else
    HASH="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
    DIRTY=""
    if [ "${HASH}" != "nogit" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        DIRTY="-dirty"
    fi
fi
VER="${BS_VERSION}"
DATE="$(date -u +%Y-%m-%dT%H:%MZ)"

# Mode + arch from the source filename (…-release-amd64.iso).
base="$(basename "${ISO}")"
MODE="dev"; case "${base}" in *-release-*) MODE="release";; esac
RELSUF=""; [ "${MODE}" = "release" ] && RELSUF="-release"

# Kernel: read from the build tree if it's still around, else from the ISO.
KERNEL="n/a"
if ls binary/live/vmlinuz-* >/dev/null 2>&1; then
    KERNEL="$(basename "$(ls binary/live/vmlinuz-* | head -n1)" | sed 's/^vmlinuz-//')"
fi

DEST="archive/BETRIEBSSYSTEM-${VER}-g${HASH}${DIRTY}${RELSUF}-amd64.iso"

log "archiving -> ${DEST}"
ln -f "${ISO}" "${DEST}" 2>/dev/null || cp -f "${ISO}" "${DEST}"
SHA="$(sha256sum "${DEST}" | cut -d' ' -f1)"
echo "${SHA}  $(basename "${DEST}")" > "${DEST}.sha256"
SIZE="$(du -h "${DEST}" | cut -f1)"

# Manifest (create header once, then append a row).
MAN="archive/MANIFEST.md"
if [ ! -f "${MAN}" ]; then
    cat > "${MAN}" <<'EOF'
# BETRIEBSSYSTEM build archive

Each row is one built ISO. The `.iso` binaries live next to this file but are
git-ignored (too large); this manifest is committed so any build is
reproducible: `git checkout <commit>` then `sudo ./scripts/build.sh`.

| Date (UTC) | Version | Commit | Mode | Kernel | Size | ISO | SHA256 |
|------------|---------|--------|------|--------|------|-----|--------|
EOF
fi
printf '| %s | %s | %s | %s | %s | %s | `%s` | `%s` |\n' \
    "${DATE}" "${VER}" "${HASH}${DIRTY}" "${MODE}" "${KERNEL}" "${SIZE}" \
    "$(basename "${DEST}")" "${SHA}" >> "${MAN}"

log "archived: ${DEST} (${SIZE}, ${KERNEL})"
[ -n "${DIRTY}" ] && warn "working tree was DIRTY at archive time -- commit hash does not fully capture the build"
log "manifest updated: ${MAN}"
