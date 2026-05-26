# CLAUDE.md — operating guide for BETRIEBSSYSTEM

Guidance for Claude Code (and humans) working in this repo. Keep it accurate;
see **§ Self-update protocol** at the bottom — updating this file is part of
the job, not an afterthought.

## What this project is

A git-tracked builder for **BETRIEBSSYSTEM**, a Debian 13 (*trixie*) live/install
ISO: minimal GNOME 48 on Wayland/Mutter, root-on-ZFS for installed systems, and
a deliberately content-free identity (a white circle on black, everywhere).

The image is defined **declaratively** by `auto/config` + the `config/` tree and
built by the standard Debian tool **`live-build`** (`lb`). There is no bespoke
bootstrapping — we lean on `lb` and add branding, packages, hooks, and an
installer config on top.

## Invariants (do not break these without telling the user)

1. **Identity = white circle on black.** No text logos, no Debian/vendor marks
   in anything user-visible. All visuals derive from `branding/brand.json` via
   `branding/generate.py`. If you add a surface that shows a logo, render it
   from that source, don't hand-place an image.
2. **One source of truth per concern.** The ISO definition lives in
   `auto/config`; packages in `config/package-lists/`; baked files in
   `config/includes.chroot/`; ISO-only files in `config/includes.binary/`;
   build-time actions in `config/hooks/normal/`. Don't scatter equivalents.
3. **Reproducible & git-tracked.** Never commit `lb`-generated control files or
   build artifacts (`.gitignore` already filters them — extend it if `lb`
   starts emitting something new into `config/`).
4. **Root-on-ZFS is the target for installed systems.** Don't quietly swap the
   default filesystem.

## Architecture map

| Path | Role |
|------|------|
| `auto/config` | The entire `lb config` call. Suite, areas, bootloaders, ISO metadata, boot append. **Edit here to change the image shape.** |
| `auto/build`, `auto/clean` | Thin logged wrappers around `lb build` / `lb clean`. |
| `config/package-lists/*.list.chroot` | Packages, grouped: `00-desktop` (GNOME), `10-live`, `20-zfs`, `30-installer` (Calamares), `40-base`. |
| `config/includes.chroot/` | Files copied into the system at their absolute paths: `etc/os-release`, hostname, `etc/dconf/**` (GNOME defaults), `etc/calamares/**` (installer), Plymouth theme, skel desktop launcher. |
| `config/includes.binary/boot/grub/betriebssystem/` | GRUB theme (`theme.txt` + generated `background.png`). |
| `config/hooks/normal/` | Build hooks. `*.hook.chroot` run in the chroot; `*.hook.binary` run in the binary/ISO stage. Numbered for ordering. |
| `branding/brand.json` + `generate.py` | Source of truth + rasterizer for all visual assets. |
| `scripts/build.sh` | Root orchestrator: deps → branding → mode marker → `lb clean/config/build` → collect ISO into `dist/`. |
| `scripts/run-qemu.sh` | Boot an ISO: KVM autodetect, BIOS/UEFI, optional ZFS-install test disk. |
| `scripts/lib.sh` | Shared bash helpers (logging, `require_root`, `restore_ownership`, `kvm_available`). |

### Build hooks, in order

- `0100-branding.hook.chroot` — set Plymouth default theme; make launcher exec.
- `0100-grub-theme.hook.binary` — point GRUB at our theme; rename menu titles to BETRIEBSSYSTEM.
- `0200-dconf.hook.chroot` — `dconf update` so GNOME defaults apply.
- `0300-zfs-check.hook.chroot` — **fails the build** if `zfs.ko` didn't build for the live kernel.
- `0900-initramfs.hook.chroot` — rebuild initramfs (embeds Plymouth + ZFS).
- `9000-release-scrub.hook.chroot` — if `/etc/.bs-buildmode` == `release`, scrub cosmetic tells; always remove the marker.

## How to work here

- **Build:** `sudo ./scripts/build.sh` (dev) / `sudo RELEASE=1 ./scripts/build.sh`
  (release). Needs real root — `live-build` bootstraps a chroot and mounts
  pseudo-filesystems; it cannot run unprivileged. Build takes 20–60+ min.
- **Validate config without building:** `lb config` runs unprivileged and
  catches bad `lb` options — always run it after editing `auto/config`.
- **Run:** `./scripts/run-qemu.sh [--uefi] [--disk]`.
- **Branding:** edit `brand.json`, then `make branding`.
- **After a privileged build**, `build.sh` re-chowns the tree back to `$SUDO_USER`
  so the git checkout isn't root-owned. Keep that behavior if you touch it.

## Gotchas / things that bit us

- `lb config` symlinks **stock live-build hooks** into `config/hooks/normal/`
  and `config/hooks/live/`, and writes a default `config/package-lists/live.list.chroot`.
  `.gitignore` excludes those and force-includes only our six authored hooks.
  If you add a hook, add a matching `!`-include line.
- Chroot hooks **don't inherit the parent shell's env**. Build mode crosses into
  the chroot via the `/etc/.bs-buildmode` marker file (written by `build.sh`,
  consumed+deleted by `9000-release-scrub`). Use the same pattern for new
  build-mode-dependent behavior.
- **ZFS module:** `zfs-dkms` + `linux-headers-amd64` build `zfs.ko` at chroot
  time. If headers and kernel ever drift, `0300-zfs-check` will fail the build —
  that's intentional.
- **Calamares root-on-ZFS** (`etc/calamares/`) is the least-tested area and is
  version-sensitive (trixie ships Calamares ~3.3.14). If an install fails in the
  partition/zfs/mount stages, that config is the first suspect. The module
  config schema (`zfs.conf`, `partition.conf`) may need adjusting to the exact
  module version. The live-environment ZFS support is solid; the *guided
  installer onto ZFS* is what to verify on real hardware/VM.
- **KVM:** the dev user here is not in the `kvm` group, so `run-qemu.sh` falls
  back to slow TCG. `sudo usermod -aG kvm "$USER"` + re-login fixes it.
- The user cannot give Claude passwordless root in the default setup, so the
  human runs `sudo ./scripts/build.sh` themselves; Claude scaffolds and iterates
  on everything else.

## Roadmap / open items

- [ ] Validate a real root-on-ZFS install end-to-end in a VM and lock down the
      Calamares `zfs`/`partition`/`mount` config to the trixie module version.
- [ ] Confirm GDM autologin for the live `user` (live-config should handle it;
      verify on first boot).
- [ ] Verify the GRUB theme actually renders (background + colors) in both BIOS
      and UEFI; the menu-title rebrand is robust, the themed background is
      best-effort and untested here.
- [ ] Optional: native ZFS encryption flow (toggle in `etc/calamares/modules/zfs.conf`).

## Self-update protocol

This file is meant to stay true as the project changes. When you (Claude) make a
change in this repo, **before finishing**:

1. If you changed the **architecture, build flow, branding pipeline, hooks, or
   invariants**, update the relevant section here in the same commit.
2. If you **resolved** a roadmap/open item, check it off or remove it. If you
   discovered a new sharp edge, add it under **Gotchas**.
3. Keep the **Architecture map** table and **hooks-in-order** list in sync with
   what's actually on disk (`config/hooks/normal/`, `config/package-lists/`).
4. Don't let this file drift into aspiration — describe what the repo *does*
   now. Move future intentions to **Roadmap**.
5. Keep it concise. If a section grows stale or redundant, prune it.
