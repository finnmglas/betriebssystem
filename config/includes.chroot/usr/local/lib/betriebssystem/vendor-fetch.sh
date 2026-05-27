# shellcheck shell=sh
# vendor-fetch.sh -- cached downloads for build hooks. Source, don't execute.
#
# Build.sh bind-mounts the host's cache/vendor/ over ${VENDOR_DIR} for the chroot
# stage, so files fetched during a build are reused by later builds instead of
# being re-downloaded. The mount is unmounted before lb binary, so nothing here
# ends up in the image (only this ~1 KB helper does).
#
# vendor_get URL DEST
#   Populate DEST from the cache if present, else download from URL and cache it.
#   Returns 0 on success (DEST exists and is non-empty), non-zero otherwise.
#   A cold cache (or no mount) behaves exactly like a plain curl -- so callers
#   can keep their existing network fallbacks and nothing breaks offline.

VENDOR_DIR="${VENDOR_DIR:-/var/cache/bs-vendor}"

vendor_get() {
    _vg_url="$1"; _vg_dest="$2"
    [ -n "${_vg_url}" ] && [ -n "${_vg_dest}" ] || return 2
    _vg_key="$(printf '%s' "${_vg_url}" | sha256sum | cut -d' ' -f1)"
    _vg_cached="${VENDOR_DIR}/${_vg_key}"

    if [ -s "${_vg_cached}" ] && cp "${_vg_cached}" "${_vg_dest}" 2>/dev/null; then
        echo "I: vendor cache hit -> $(basename "${_vg_dest}")"
        return 0
    fi

    command -v curl >/dev/null 2>&1 || return 1
    if curl -fsSL "${_vg_url}" -o "${_vg_dest}" 2>/dev/null && [ -s "${_vg_dest}" ]; then
        # Best-effort cache write; failure (e.g. no mount) is non-fatal.
        if [ -d "${VENDOR_DIR}" ] || mkdir -p "${VENDOR_DIR}" 2>/dev/null; then
            cp "${_vg_dest}" "${_vg_cached}" 2>/dev/null || true
        fi
        return 0
    fi
    return 1
}
