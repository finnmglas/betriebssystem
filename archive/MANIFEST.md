# BETRIEBSSYSTEM build archive

Each row is one built ISO. The `.iso` binaries live next to this file but are
git-ignored (too large); this manifest is committed so any build is
reproducible: `git checkout <commit>` then `sudo ./scripts/build.sh`.

| Date (UTC) | Version | Commit | Mode | Kernel | Size | ISO | SHA256 |
|------------|---------|--------|------|--------|------|-----|--------|
| 2026-05-26T11:21Z | 0.1.0 | 5a806a9 | dev | 6.12.90+deb13-amd64 | 1.9G | `BETRIEBSSYSTEM-0.1.0-g5a806a9-amd64.iso` | `364fe0f29b806c38b4981ff9c586a0be59eec459734ace6e5f1c463dd72f3e54` |
| 2026-05-26T11:46Z | 0.1.0 | 34310ef | dev | 6.12.90+deb13-amd64 | 1.9G | `BETRIEBSSYSTEM-0.1.0-g34310ef-amd64.iso` | `93cf9386c31d48a54d194440a4192ef4d923370f29e075026679a63645a46999` |
