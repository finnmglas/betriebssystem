#!/usr/bin/env bash
#
# verify-packages.sh -- pre-flight check that every package named in
# config/package-lists/*.list.chroot resolves against the apt indices, so a
# typo or a removed package fails in SECONDS instead of 20 minutes into a build.
#
# Runs against the host's apt cache (the host is the same trixie suite). It is a
# name/availability check, not a full dependency solve. Packages that come from
# repos added via config/archives/ (and so may be absent from the host) are
# listed in THIRDPARTY and reported as pre-verified rather than failed.
#
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "${BS_ROOT}"

# Packages provided by config/archives/*.list.chroot (verified out-of-band).
THIRDPARTY="code claude-code"

LISTS=$(ls config/package-lists/*.list.chroot 2>/dev/null || true)
[ -n "${LISTS}" ] || die "no package lists found"

pkgs=$(grep -hvE '^\s*#|^\s*$' ${LISTS} | awk '{print $1}' | sort -u)

missing=0; checked=0; skipped=0
for p in ${pkgs}; do
    checked=$((checked + 1))
    case " ${THIRDPARTY} " in
        *" ${p} "*) skipped=$((skipped + 1)); continue ;;
    esac
    c=$(apt-cache policy "${p}" 2>/dev/null | awk '/Candidate:/{print $2; exit}')
    if [ -z "${c}" ] || [ "${c}" = "(none)" ]; then
        warn "UNRESOLVED: ${p}"
        missing=$((missing + 1))
    fi
done

log "checked ${checked} packages (${skipped} third-party pre-verified: ${THIRDPARTY})"
if [ "${missing}" -gt 0 ]; then
    die "${missing} package(s) do not resolve -- fix the list(s) before building"
fi
log "all package-list entries resolve"

# Phase 2: a real dependency solve, to catch CONFLICTS (e.g. rustc vs rustup)
# that a name-existence check misses. apt-get -s needs no root; it runs against
# the host's state (same trixie suite + areas), excluding third-party packages
# the host's repos may lack.
solve=""
for p in ${pkgs}; do
    case " ${THIRDPARTY} " in *" ${p} "*) continue ;; esac
    solve="${solve} ${p}"
done
# Dir::State::status=/dev/null makes apt solve as if NOTHING is installed, so the
# host's own packages (e.g. its OpenZFS build) can't create false conflicts --
# this mirrors a fresh chroot.
log "dependency solve (apt-get -s install, fresh-system view)..."
if ! out=$(apt-get install -s -o Dir::State::status=/dev/null ${solve} 2>&1); then
    echo "${out}" | grep -iE 'conflict|unmet|unable to locate|broken|could not be installed|conflicting' | sed 's/^/    /' >&2
    die "dependency solve failed -- conflict or unmet dependency (see above)"
fi
log "dependency solve clean -- no conflicts"
