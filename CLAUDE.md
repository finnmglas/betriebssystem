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
| `scripts/build.sh` | Root orchestrator: deps → branding → mode marker → `lb clean/config/build` → collect ISO into `dist/` → archive a hash-stamped copy. |
| `scripts/run-qemu.sh` | Boot an ISO: KVM autodetect, BIOS/UEFI, optional ZFS-install test disk. |
| `scripts/archive-iso.sh` | Hardlink the ISO into `archive/` named with the git commit hash; append a row to the tracked `archive/MANIFEST.md`. `BS_ARCHIVE_COMMIT` overrides the stamped commit. |
| `archive/MANIFEST.md` | Tracked log of every archived build (date, version, commit, mode, kernel, size, sha256). ISO binaries beside it are git-ignored. |
| `scripts/lib.sh` | Shared bash helpers (logging, `require_root`, `restore_ownership`, `kvm_available`). |

### Build hooks, in order (authored hooks use the 0xxx range; stock live-build hooks start at 1000)

- `0100-branding.hook.chroot` — set Plymouth default theme; make launcher exec.
- `0100-grub-theme.hook.binary` — force our GRUB theme, rename menu titles to BETRIEBSSYSTEM, drop the boot beep, inject the "Install BETRIEBSSYSTEM" entry.
- `0150-wine-multiarch.hook.chroot` — enable i386, install Wine 32/64-bit (guarded).
- `0200-dconf.hook.chroot` — `dconf update` so GNOME defaults/favorites apply.
- `0240-locale-keyboard.hook.chroot` — `locale-gen` en_US.UTF-8 (German keyboard via /etc/default/keyboard).
- `0250-xonsh.hook.chroot` — register xonsh; make interactive bash `exec xonsh`.
- `0260-desktop-db.hook.chroot` — rebuild MIME + desktop DBs (file associations).
- `0300-pipx.hook.chroot` — JupyterLab + PlatformIO system-wide via pipx (guarded, network).
- `0300-zfs-check.hook.chroot` — **fails the build** if `zfs.ko` didn't build for the live kernel.
- `0310-embedded.hook.chroot` — arduino-cli + PlatformIO udev rules (guarded, network).
- `0400-flatpak.hook.chroot` — add Flathub remote; enable `betriebssystem-firstboot.service`.
- `0410-flatpak-seed.hook.chroot` — **bake** Logseq/Android Studio/Arduino IDE2 into the image (guarded); first-boot service is the fallback.
- `0420-vscode-ext.hook.chroot` — preinstall VS Code extensions into `/etc/skel` (guarded; `code --install-extension` as root needs `--no-sandbox`).
- `0900-initramfs.hook.chroot` — rebuild initramfs (embeds Plymouth + ZFS).
- `9000-release-scrub.hook.chroot` — if `/etc/.bs-buildmode` == `release`, scrub cosmetic tells; always remove the marker.

### Software stack (the "real distro" layer)

- **apt** (verified, in `config/package-lists/`): GNOME, LibreOffice, Firefox-ESR,
  emulators (mgba/dolphin/stella/atari800/hatari/mupen64/desmume/nestopia/mednafen
  + RetroArch & cores), languages (py/node/go/rust/java/kotlin/ruby/lua/php/fortran/
  lisp + build tooling), virt (docker/qemu/gnome-boxes/virt-manager/libvirt),
  embedded (arduino/esptool/serial), drivers/firmware, shells (xonsh/zsh/fzf/zoxide).
- **Third-party apt repos** (`config/archives/`, key in trusted.gpg.d): VS Code
  (`code`, Microsoft), Claude Code (`claude-code`, Anthropic — verified genuine repo).
- **Flatpak (first boot, installed systems only)**: Logseq, Android Studio, Arduino IDE 2.
- **pipx (system-wide /opt/pipx)**: JupyterLab, PlatformIO.
- **Wine** (i386 multiarch) for `.exe`. **File associations**: custom MIME types +
  self-owned launcher `.desktop`s map `.gba/.gb/.gbc/.nes/.n64/.nds` → emulators,
  `.exe/.msi` → Wine, `.apk` → Waydroid (post-install). `.iso` intentionally NOT remapped.
- **Waydroid (APKs)**: NOT baked in — needs binder/Wayland and post-install setup.

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

- **`.hook.binary` runs with CWD = `binary/`** (live-build does `cd binary`
  first), so paths inside binary hooks are relative to `binary/` (e.g.
  `boot/grub`, *not* `binary/boot/grub`). `.hook.chroot` runs with CWD `/`.
  This bit us once — the GRUB theme hook silently skipped on the first build.
- **GRUB menu titles** are `Live system (amd64)` etc. (not "Debian"), and the
  theme is gated by live-build's `boot/grub/theme.cfg` (only themes if
  `splash.png` exists). Our binary hook overwrites `theme.cfg` to force our
  theme and renames the "Live system" titles. Confirm both still match if
  live-build changes its grub templates.
- `lb config` symlinks **stock live-build hooks** into `config/hooks/normal/`
  and `config/hooks/live/`, and writes a default `config/package-lists/live.list.chroot`.
  `.gitignore` excludes those; authored hooks are tracked via the `0*.hook.*`
  glob (stock hooks start at 1000), plus the one `9000-release-scrub`. **Name new
  authored hooks in the 0xxx range** or they won't be tracked.
- **Package lists take ONE package per line, no inline `#` comments** — live-build
  passes lines to apt verbatim. Use full-line comments only.
- **Wine needs i386 multiarch**, which a package list can't enable; it's installed
  in `0150-wine-multiarch.hook.chroot` after bootstrap. Same pattern for anything
  needing `dpkg --add-architecture` or apt actions mid-build.
- **Archive areas have TWO variables.** `--archive-areas` sets `LB_ARCHIVE_AREAS`
  but the chroot's main Debian `sources.list` is generated from
  `LB_PARENT_ARCHIVE_AREAS` — you must set **`--parent-archive-areas` too**, or
  the extra component (we hit this with `non-free` → `libretro-snes9x` "Unable to
  locate package"). `auto/config` sets both. `verify-packages.sh` checks the host
  (which has the same areas), so keep host and chroot areas aligned.
- **`config/archives/*.list.chroot` + `*.key.chroot`** add signed third-party
  repos; live-build sets them up BEFORE package install, so repo packages can go
  in normal package lists. Keys land in `/etc/apt/trusted.gpg.d/` (global trust),
  so no `signed-by=` needed; use `[arch=amd64]` to avoid i386 fetch errors.
- **`scripts/verify-packages.sh`** is a pre-flight (run by build.sh): it checks
  every list entry resolves AND runs a dependency solve (`apt-get -s install -o
  Dir::State::status=/dev/null`, a fresh-system view so the host's own packages
  don't cause false conflicts) to catch CONFLICTS like rustc-vs-rustup. Add
  genuinely-third-party names to its `THIRDPARTY` allowlist.
- **rustc/cargo vs rustup conflict**: they're mutually exclusive in Debian. We
  ship system `rustc`+`cargo` (works offline); don't re-add `rustup`.
- **Flatpak/pipx/arduino-cli run at build (network) or first boot**, not cached
  in-repo (only apt .debs persist in `cache/`). The first-boot Flatpak service is
  gated `!/run/live/medium` so it never runs in a live session.
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
- [x] First successful build: `BETRIEBSSYSTEM-0.1.0-amd64.iso`, 1.9 GB, ZFS
      module built against 6.12.90, boots in QEMU (2026-05-26, commit 5a806a9).
- [x] Fixed + verified the GRUB theme hook (wrong CWD assumption — see Gotchas):
      themed background and renamed "BETRIEBSSYSTEM" menu confirmed in QEMU on
      build g34310ef (2026-05-26).
- [ ] Optional: native ZFS encryption flow (toggle in `etc/calamares/modules/zfs.conf`).
- [x] **Full software-stack build succeeded** (2026-05-26, commit gf51427a):
      4.1 GB ISO (flatpaks/Android Studio deferred to first boot), VS Code +
      Claude Code repos worked, all 119 pkgs installed, GRUB install entry added.
      Boot-test in QEMU underway — still confirm the guarded network hooks landed
      (VS Code, claude CLI, Wine, JupyterLab, PlatformIO, arduino-cli).
- [ ] Verify the rebuild (2026-05-26 polish): xonsh highlighting (monokai),
      `cls`/aliases, fastfetch greeting; German keyboard + English locale;
      GNOME hot-corner + Nautilus power combo; Templates (incl. ODF); VS Code
      quiet/no-keyring + extensions; Flatpaks baked in & present in live. ISO ~6.5-7G.
- [ ] Confirm `flatpak install` actually works in the chroot (0410); if not, it
      warns and the first-boot service covers installed systems only.
- [ ] Verify on first boot: dash favorites populate, xonsh is the terminal shell,
      `.gba`/`.exe` double-click associations work, GRUB "Install" entry launches
      Calamares (the `betriebssystem-install` autostart path).
- [ ] Verify the first-boot Flatpak service installs Logseq/Android Studio/Arduino
      IDE 2 on an installed system (and stays off in live).
- [ ] Possible follow-ups: cache vendored downloads (arduino-cli, pip wheels) into
      `cache/vendor/`; Waydroid post-install setup script; trim ISO size.

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
