# BETRIEBSSYSTEM — Quickstart

From a clean checkout to a booted desktop in three steps.

## 0. Prerequisites (once)

A Debian/Ubuntu host with `sudo`. Build deps install automatically on first
build, or install them now:

```bash
make deps
sudo apt-get install -y qemu-system-x86 ovmf   # ovmf only needed for --uefi
```

## 1. Build the ISO

`live-build` must run as root (it bootstraps a chroot). The build downloads
packages and takes **20–60+ minutes** the first time; later builds reuse the
package cache.

```bash
sudo ./scripts/build.sh
```

Output: `dist/BETRIEBSSYSTEM-0.1.0-amd64.iso` (+ a `.sha256`).

For a release image with build tells scrubbed:

```bash
sudo RELEASE=1 ./scripts/build.sh
# -> dist/BETRIEBSSYSTEM-0.1.0-release-amd64.iso
```

## 2. Boot it in QEMU

```bash
./scripts/run-qemu.sh                 # newest dist/*.iso, BIOS, KVM if available
./scripts/run-qemu.sh --uefi          # UEFI / OVMF
./scripts/run-qemu.sh --uefi --disk   # + blank 32G disk to test installing to ZFS
```

You should see: a black screen with a breathing white circle (Plymouth) →
GDM (dark, white-circle logo) → a GNOME/Wayland desktop with an **Install
BETRIEBSSYSTEM** launcher.

## 3. Iterate

```bash
make branding     # re-render the white-circle assets after editing brand.json
make clean        # drop build artifacts (keeps package cache -> fast rebuild)
sudo ./scripts/build.sh
```

## Common knobs

| Want to…                    | Do this                                                    |
|-----------------------------|------------------------------------------------------------|
| Add a package               | add it to a list in `config/package-lists/*.list.chroot`   |
| Change the circle size      | edit `circle_diameter_fraction` in `branding/brand.json`   |
| Change Debian suite / mirror| `BS_DISTRIBUTION=...` / `BS_MIRROR=...` before `build.sh`   |
| Bake in a file              | drop it under `config/includes.chroot/<abs-path>`          |
| Run a build-time command    | add `config/hooks/normal/NNNN-name.hook.chroot`            |

See [`CLAUDE.md`](CLAUDE.md) for the full architecture.
