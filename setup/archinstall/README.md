# archinstall profiles

Saved `archinstall` configurations — the layer *below* `setup/arch.sh`.

`setup/arch.sh` assumes a booting Arch system with a user account. These files
describe how that system is partitioned and installed, so a rebuild does not
depend on remembering the disk layout.

## Usage

```bash
archinstall --config urakara.json
```

Then set credentials interactively when prompted.

Do **not** reuse a saved `user_credentials.json`. It holds argon2id password
hashes, never belongs in this repo, and archinstall regenerates it on each run.

## Profiles

| file | machine | notes |
|---|---|---|
| `urakara.json` | ThinkPad T470s (LENOVO 20L8S0YW00) | GRUB, btrfs, `/dev/nvme0n1` |

## urakara.json

Captured from archinstall 3.0.9, verified against the running machine.

- **bootloader** GRUB, 1 GiB fat32 ESP at `/boot`
- **root** btrfs on `/dev/nvme0n1p2`, `compress=zstd`, subvolumes
  `@` → `/`, `@home` → `/home`, `@log` → `/var/log`, `@pkg` → `/var/cache/pacman/pkg`
- **snapshots** `snapshot_config.type = Timeshift` — archinstall wires this up,
  not `setup/arch.sh`
- **profile** `Minimal`, no greeter, no gfx driver, `packages: []` — every
  package and all desktop configuration comes from `setup/arch.sh`
- **locale** `en_US.UTF-8`, `us` keymap, `America/Vancouver`, NTP on, swap on

### Hardware-bound values

These are specific to this laptop and must be reviewed before use elsewhere:

- `disk_config.device_modifications[0].device` — `/dev/nvme0n1`
- `...partitions[].size.value` — exact byte counts for a 931.5 GB drive
- `wipe: true` — **destroys the named device**; confirm the path first
- `hostname` — `urakara`

For a different machine, run `archinstall` interactively, save the config, and
add it here as a new file rather than editing this one.

The large `mirror_config` block is kept verbatim so this reproduces the original
install exactly. It can be trimmed to the region selection if it becomes noisy.
