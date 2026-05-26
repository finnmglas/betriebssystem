<div align="center">

![BETRIEBSSYSTEM](branding/out/betriebssystem-1024.png)

# BETRIEBSSYSTEM

A minimal, modern Debian-based operating system.
GNOME on Wayland, root-on-ZFS, and a single white circle for a face.

</div>

---

## What this is

`BETRIEBSSYSTEM` is a buildable, git-tracked Debian live/install image:

- **Base:** Debian 13 *trixie* (`main contrib non-free-firmware`).
- **Desktop:** GNOME 48 on **Wayland**, composited by **Mutter** — the modern
  compositor. Dark by default.
- **Filesystem:** the **installed** system runs on **ZFS** (root-on-ZFS via the
  Calamares installer). The live image itself boots from squashfs (unavoidable
  for live media) but ships full ZFS tooling and the kernel module.
- **Identity:** no logos, no wordmarks, no vendor noise — just a **white circle
  on black** everywhere (boot splash, GRUB, wallpaper, login, installer).
- **Boot:** a single hybrid ISO that boots on both **BIOS and UEFI** via GRUB,
  offering **live boot** and an **Install** entry.
- **Two build flavours:** a `dev` build, and a `release` build that scrubs the
  cosmetic tells that it was assembled with Debian live-build.

The whole image is defined declaratively by [`auto/config`](auto/config) and the
`config/` tree, so it is reproducible and extensible. See
[`CLAUDE.md`](CLAUDE.md) for the architecture and how to extend it.

## Quickstart

> Full details in [`QUICKSTART.md`](QUICKSTART.md).

```bash
# 1. Build an ISO (needs root: live-build bootstraps a chroot). 20-60+ min.
sudo ./scripts/build.sh

# 2. Boot it in QEMU.
./scripts/run-qemu.sh
```

### Run it in QEMU (copy-paste)

The newest ISO in `dist/` is picked up automatically. Pick the line you want:

```bash
# Legacy BIOS, KVM-accelerated if available, GTK window:
./scripts/run-qemu.sh

# UEFI firmware (OVMF) instead of BIOS:
./scripts/run-qemu.sh --uefi

# UEFI + a blank 32G virtio disk, to actually test installing to root-on-ZFS:
./scripts/run-qemu.sh --uefi --disk
```

Prefer raw QEMU? This is the equivalent of the default runner (replace the ISO
path), KVM-accelerated:

```bash
qemu-system-x86_64 \
  -name BETRIEBSSYSTEM -machine q35 -m 4096 -smp 4 \
  -enable-kvm -cpu host \
  -vga virtio -display gtk \
  -device qemu-xhci -device usb-tablet \
  -cdrom dist/BETRIEBSSYSTEM-0.1.0-amd64.iso -boot d
```

If `/dev/kvm` isn't usable for your user, drop `-enable-kvm -cpu host` and add
`-cpu max` (software emulation — much slower). To join the KVM group:
`sudo usermod -aG kvm "$USER"` then re-login.

## Prerequisites

A Debian/Ubuntu host. The build installs what it needs on first run, or:

```bash
make deps         # installs: live-build debootstrap squashfs-tools xorriso
                  # mtools dosfstools grub-pc-bin grub-efi-amd64-bin python3-pil
```

QEMU for running: `sudo apt-get install qemu-system-x86 ovmf` (`ovmf` only for
`--uefi`).

## Build flavours

| Command          | Result                                                        |
|------------------|---------------------------------------------------------------|
| `make build`     | `dev` ISO → `dist/BETRIEBSSYSTEM-<ver>-amd64.iso`             |
| `make release`   | `release` ISO → `dist/BETRIEBSSYSTEM-<ver>-release-amd64.iso` |

`release` runs an extra chroot hook that blanks the MOTD, removes live-build
version breadcrumbs, rewrites `lsb_release` to report `BETRIEBSSYSTEM`, and
drops apt/dpkg logs that leak build timestamps. (A live ISO still contains
`live-boot`/`live-config` — that machinery is what lets it boot from squashfs —
so this is a *cosmetic* scrub, not a claim that the image is indistinguishable
from a from-scratch distro.)

## Build archive

Every build is hardlinked into `archive/` with the **git commit hash** in its
name (e.g. `BETRIEBSSYSTEM-0.1.0-g5a806a9-amd64.iso`), and a row is appended to
the git-tracked [`archive/MANIFEST.md`](archive/MANIFEST.md) (date, version,
commit, mode, kernel, size, sha256). The hardlink costs no extra disk.

This means any past build is reproducible — `git checkout <commit>` then
`sudo ./scripts/build.sh` — and the manifest is your index of what was built
when. The `.iso` binaries are git-ignored (too large); the manifest is not.

```bash
make archive      # file the newest dist/ ISO into the archive manually
```

## Branding

Everything visual derives from one source of truth,
[`branding/brand.json`](branding/brand.json): background `#000000`, foreground
`#ffffff`, circle diameter as a fraction of the frame. Regenerate every asset:

```bash
make branding     # python3 branding/generate.py
```

This rewrites the Plymouth logo, GRUB background, wallpaper, and the app /
login / Calamares logos, plus the canonical `branding/logo.svg`.

## Project layout

```
auto/config                 # the whole `lb config` invocation (edit this)
config/package-lists/       # what packages go in (desktop, live, zfs, installer, base)
config/includes.chroot/     # files baked into the system (os-release, dconf, calamares, plymouth)
config/includes.binary/     # files placed on the ISO (GRUB theme)
config/hooks/normal/        # build-time hooks (branding, dconf, zfs check, initramfs, scrub)
branding/                   # brand.json + generate.py + generated assets
scripts/                    # build.sh, run-qemu.sh, archive-iso.sh, bootstrap-deps.sh, lib.sh
dist/                       # latest built ISO (gitignored)
archive/                    # hash-stamped ISOs (gitignored) + MANIFEST.md (tracked)
```

## Caveats / known soft spots

- **Build needs root.** `live-build` bootstraps a chroot and mounts pseudo-fs.
- **Root-on-ZFS via Calamares** (`config/includes.chroot/etc/calamares/`) is the
  least battle-tested piece and may need tuning against the exact Calamares
  version in trixie. The live environment's ZFS support (import/create pools) is
  straightforward; the *guided install onto ZFS* is the part to validate.
- The live ISO boots from squashfs, not ZFS — see "What this is" above.

## License

MIT for the build tooling and branding (see [`LICENSE`](LICENSE)). A built ISO
bundles Debian and many packages under their own licenses.
