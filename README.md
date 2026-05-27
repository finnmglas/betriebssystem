<div align="center">

![BETRIEBSSYSTEM](branding/out/betriebssystem-1024.png)

# BETRIEBSSYSTEM

An AI-ready Linux distribution — live-built from the terminal, shipping
everything an agentic developer workload needs out of the box.
GNOME on Wayland, root-on-ZFS, and a single white circle for a face.

</div>

> *Betriebssystem* is the German word for **operating system** (OS).

---

## What this is

An AI-ready Linux distribution / operating system that can be **live-built from
the terminal**, and ships with everything needed to run agentic developer
workloads out of the box: **Claude**, **VS Code**, **Docker**, **Ollama**, **ML
libraries**, **emulators**, and full **multimedia codecs**.

Under the hood it's a buildable, git-tracked Debian live/install image:

- **Base** — Debian 13 *trixie* (`main contrib non-free-firmware`).
- **Desktop** — GNOME 48 on **Wayland**/Mutter, dark by default.
- **Filesystem** — the **installed** system runs on **root-on-ZFS** (via the
  Calamares installer). The live ISO boots from squashfs but ships full ZFS tooling.
- **Identity** — no logos or wordmarks, just a **white circle on black**
  everywhere (boot splash, GRUB, wallpaper, login, installer).
- **Boot** — one hybrid ISO for **BIOS and UEFI**, with a live boot and an
  **Install** entry.

The whole image is defined declaratively by [`auto/config`](auto/config) and the
`config/` tree, so it's reproducible and extensible. The three things you'll
actually do — **build**, **run**, **dev** — are below.

## What's included

A batteries-included workstation, not a minimal shell:

- **Dev** — VS Code, Claude Code (CLI), Git/LFS, build toolchain; Python · Node ·
  Go · Rust · Java · Kotlin · Ruby · Lua · PHP · Fortran · Lisp; JupyterLab +
  PlatformIO; Docker. Local AI: an `/opt/ai-venv` stack + Ollama.
- **Shell** — xonsh interactive shell (bash stays the login shell), fzf + zoxide.
- **Emulation** — double-click a ROM and it runs (`.gba/.gb/.gbc/.nes/.n64/.nds`
  via mGBA/Dolphin/Mupen64/DeSmuME/Nestopia/RetroArch); `.exe`/`.msi` → Wine;
  `.apk` → Waydroid (post-install).
- **Virt / embedded** — GNOME Boxes, virt-manager, QEMU/KVM, libvirt; Arduino,
  ESP32, serial tooling.
- **Apps / media** — LibreOffice, Firefox, Chrome, GIMP/Inkscape/Audacity,
  Blender + CAD/slicers, full codecs; Logseq/Android Studio/Arduino IDE (first boot).

See [`CLAUDE.md`](CLAUDE.md) for the complete software map.

---

## Build

Needs a **Debian/Ubuntu host** and **root** — `live-build` bootstraps a chroot
and mounts pseudo-filesystems, so it can't run unprivileged.

```bash
make deps                  # install host build deps (once)
sudo ./scripts/build.sh    # build a dev ISO  → dist/BETRIEBSSYSTEM-0.1.0-amd64.iso
```

First build downloads packages and takes **20–60+ min**; later builds reuse the
apt cache in `cache/` (gitignored), so they're much faster. A `.sha256` is
written next to the ISO, and every build is also filed into
[`archive/`](archive/MANIFEST.md) stamped with its git commit.

For a **release** ISO (scrubs the cosmetic tells that it was assembled with
live-build):

```bash
make release               # → dist/BETRIEBSSYSTEM-0.1.0-release-amd64.iso
```

> Expect a release ISO around **8–15 GB** with the full stack. Flatpak/pipx/
> arduino-cli fetch over the network at build or first boot.

## Run

Boots the newest ISO in `dist/`. KVM is auto-detected (falls back to slow TCG).

```bash
make run                   # BIOS,         16G RAM / 8 vCPU
make run-uefi              # UEFI (OVMF)
make run-install           # UEFI + a blank disk, to test installing to ZFS
```

These wrap [`scripts/run-qemu.sh`](scripts/run-qemu.sh), which takes more knobs
(`--ram=`, `--cpus=`, `--disk-size=`, `--no-gl`, …). You should see: a breathing
white circle (Plymouth) → GDM → a GNOME desktop with an **Install BETRIEBSSYSTEM**
launcher.

Running QEMU needs `qemu-system-x86` (and `ovmf` for `--uefi`):

```bash
sudo apt-get install -y qemu-system-x86 ovmf
```

If `/dev/kvm` isn't usable for your user: `sudo usermod -aG kvm "$USER"`, then
re-login.

## Dev

The inner loop — edit, rebuild, boot:

```bash
# edit auto/config, config/**, or branding/brand.json …
lb config                  # validate auto/config (unprivileged, fast)
make branding              # re-render white-circle assets after editing brand.json
make clean                 # drop artifacts, keep apt cache → fast rebuild
sudo ./scripts/build.sh
make run
```

Common changes:

| Want to…                     | Do this                                                    |
|------------------------------|------------------------------------------------------------|
| Add a package                | add it to a list in `config/package-lists/*.list.chroot`   |
| Bake a file into the system  | drop it under `config/includes.chroot/<absolute-path>`     |
| Run a build-time command     | add `config/hooks/normal/NNNN-name.hook.chroot` (0xxx range) |
| Change the circle size       | edit `circle_diameter_fraction` in `branding/brand.json`   |
| Change Debian suite / mirror | `BS_DISTRIBUTION=… BS_MIRROR=… sudo ./scripts/build.sh`    |

### Layout

```
auto/config              # the whole `lb config` invocation — edit to reshape the image
config/package-lists/    # what packages go in
config/includes.chroot/  # files baked into the system (os-release, dconf, calamares, plymouth)
config/includes.binary/  # files placed on the ISO (GRUB theme)
config/hooks/normal/     # build-time hooks (authored hooks use the 0xxx range)
branding/                # brand.json + generate.py + generated assets
scripts/                 # build.sh, run-qemu.sh, archive-iso.sh, bootstrap-deps.sh, lib.sh
dist/                    # newest built ISO (gitignored)
archive/                 # hash-stamped ISOs (gitignored) + MANIFEST.md (tracked)
```

**[`CLAUDE.md`](CLAUDE.md) is the architecture & contributor guide** — invariants,
the full hook order, the branding pipeline, and the gotchas that bit us. Read it
before changing the image shape.

`make help` lists every target.

---

## Known soft spots

- **Root-on-ZFS via Calamares** ([`config/includes.chroot/etc/calamares/`](config/includes.chroot/etc/calamares))
  is the least battle-tested piece and may need tuning against the exact
  Calamares version in trixie. The live ZFS support is solid; the *guided install
  onto ZFS* is what to validate on real hardware/VM.
- The live ISO boots from squashfs, not ZFS — unavoidable for live media.

## License

MIT for the build tooling and branding (see [`LICENSE`](LICENSE)). A built ISO
bundles Debian and many packages under their own licenses.
</content>
</invoke>
