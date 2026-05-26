#!/usr/bin/env bash
# Shared helpers for BETRIEBSSYSTEM build/run scripts. Source, don't execute.

# Repo root = parent of this scripts/ dir.
BS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BS_ROOT
BS_VERSION="$(cat "${BS_ROOT}/VERSION" 2>/dev/null || echo 0.0.0)"
export BS_VERSION

# ANSI (white circle vibes: white on black).
_c()  { printf '\033[%sm' "$1"; }
log()  { printf '%s[ BS ]%s %s\n' "$(_c '1;37')" "$(_c 0)" "$*"; }
warn() { printf '%s[ BS ]%s %s\n' "$(_c '1;33')" "$(_c 0)" "$*" >&2; }
die()  { printf '%s[ BS ]%s %s\n' "$(_c '1;31')" "$(_c 0)" "$*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "must run as root: sudo $0 $*"
}

# Re-own everything the build touched back to the human who ran sudo, so the
# git tree and caches aren't full of root-owned files.
restore_ownership() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        log "restoring ownership of repo to ${SUDO_USER}"
        chown -R "${SUDO_USER}:$(id -gn "${SUDO_USER}" 2>/dev/null || echo "${SUDO_USER}")" "${BS_ROOT}" 2>/dev/null || true
    fi
}

# Can the current user actually use KVM acceleration?
kvm_available() {
    [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]
}
