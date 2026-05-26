# shared/ — host ↔ VM drop folder

Anything you put in this folder on the **host** appears inside the QEMU guest at
**`/mnt/shared`** (and the **Shared** bookmark in Files), and vice-versa — a
quick way to move files in and out of a running BETRIEBSSYSTEM VM without
networking or rebuilding.

**How it works:** `scripts/run-qemu.sh` shares this directory into the VM over
QEMU's 9p virtfs (`mount_tag=bsshared`). The image carries a systemd mount unit
(`mnt-shared.mount`, gated to VMs) that mounts it at `/mnt/shared` on boot.

The contents are **git-ignored** (only this README and `.gitkeep` are tracked),
so scratch files here never end up in the repo.

Disable the share for a run with `./scripts/run-qemu.sh --no-shared`.
