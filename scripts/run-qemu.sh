#!/usr/bin/env bash
#
# run-qemu.sh -- boot a BETRIEBSSYSTEM ISO in QEMU.
#
#   ./scripts/run-qemu.sh [ISO] [options]
#
# Options:
#   --uefi           boot via UEFI/OVMF instead of legacy BIOS
#   --disk[=PATH]    attach a writable virtio disk (default run/test-disk.qcow2,
#                    created if absent) -- use this to test installing onto ZFS
#   --disk-size=SZ   size for a freshly-created test disk   (default 128G)
#   --ram=MB         guest RAM in MB                         (default 16384)
#   --cpus=N         vCPUs                                   (default 8)
#   --no-gl          disable host GL accel (if no virglrenderer on the host)
#   --no-kvm         force software emulation (TCG) even if KVM is available
#
# If no ISO is given, the newest dist/*.iso is used.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ISO=""
UEFI=0
USE_DISK=0
DISK_PATH="${BS_ROOT}/run/test-disk.qcow2"
DISK_SIZE=128G
RAM=16384
CPUS=8
NOKVM=0
GL=1

for arg in "$@"; do
    case "$arg" in
        --uefi)        UEFI=1 ;;
        --disk)        USE_DISK=1 ;;
        --disk=*)      USE_DISK=1; DISK_PATH="${arg#*=}" ;;
        --disk-size=*) DISK_SIZE="${arg#*=}" ;;
        --ram=*)       RAM="${arg#*=}" ;;
        --cpus=*)      CPUS="${arg#*=}" ;;
        --no-kvm)      NOKVM=1 ;;
        --no-gl)       GL=0 ;;
        -h|--help)     sed -n '3,22p' "$0"; exit 0 ;;
        -*)            die "unknown option: $arg" ;;
        *)             ISO="$arg" ;;
    esac
done

# Locate the ISO.
if [ -z "${ISO}" ]; then
    ISO="$(ls -1t "${BS_ROOT}"/dist/*.iso 2>/dev/null | head -n1 || true)"
fi
[ -n "${ISO}" ] && [ -f "${ISO}" ] || die "no ISO found (build one, or pass a path)"
log "ISO: ${ISO}"

QEMU=(qemu-system-x86_64 -name "BETRIEBSSYSTEM" -machine q35 -m "${RAM}" -smp "${CPUS}")

# Acceleration.
if [ "${NOKVM}" -eq 0 ] && kvm_available; then
    log "acceleration: KVM (-enable-kvm -cpu host)"
    QEMU+=(-enable-kvm -cpu host)
else
    if [ "${NOKVM}" -eq 0 ]; then
        warn "KVM not usable (need rw on /dev/kvm; add yourself to the 'kvm' group)"
    fi
    warn "falling back to software emulation -- the guest will be slow"
    QEMU+=(-cpu max)
fi

# Graphics + input. virtio-GPU with host GL (virgl) gives GNOME real 3D
# acceleration so animations are smooth (software rendering makes GNOME feel
# sluggish/"soulless"). Falls back to plain virtio with --no-gl.
if [ "${GL}" -eq 1 ]; then
    log "graphics: virtio-GPU + host GL (use --no-gl if your host lacks virglrenderer)"
    QEMU+=(-device virtio-vga-gl -display gtk,gl=on)
else
    log "graphics: virtio-GPU (no GL)"
    QEMU+=(-vga virtio -display gtk)
fi
QEMU+=(-device qemu-xhci -device usb-tablet)

# UEFI firmware (OVMF) if requested.
if [ "${UEFI}" -eq 1 ]; then
    OVMF_CODE=""
    for c in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
        [ -f "$c" ] && { OVMF_CODE="$c"; break; }
    done
    [ -n "${OVMF_CODE}" ] || die "OVMF not found -- install it:  sudo apt-get install ovmf"
    OVMF_VARS_SRC="${OVMF_CODE%CODE*}VARS${OVMF_CODE##*CODE}"
    [ -f "${OVMF_VARS_SRC}" ] || OVMF_VARS_SRC="/usr/share/OVMF/OVMF_VARS_4M.fd"
    mkdir -p "${BS_ROOT}/run"
    VARS="${BS_ROOT}/run/OVMF_VARS.fd"
    [ -f "${VARS}" ] || cp "${OVMF_VARS_SRC}" "${VARS}"
    log "firmware: UEFI (${OVMF_CODE})"
    QEMU+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}")
    QEMU+=(-drive "if=pflash,format=raw,unit=1,file=${VARS}")
else
    log "firmware: legacy BIOS (SeaBIOS)"
fi

# Optional writable target disk for testing the installer.
if [ "${USE_DISK}" -eq 1 ]; then
    mkdir -p "$(dirname "${DISK_PATH}")"
    if [ ! -f "${DISK_PATH}" ]; then
        log "creating ${DISK_SIZE} test disk: ${DISK_PATH}"
        qemu-img create -f qcow2 "${DISK_PATH}" "${DISK_SIZE}" >/dev/null
    fi
    log "attaching target disk: ${DISK_PATH}"
    QEMU+=(-drive "file=${DISK_PATH},if=virtio,format=qcow2")
fi

# Boot from the ISO.
QEMU+=(-cdrom "${ISO}" -boot d)

log "launching: ${QEMU[*]}"
exec "${QEMU[@]}"
