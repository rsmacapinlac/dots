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
| `vm-test.json` | libvirt VM, 60 GiB virtio disk | rehearsal target, `/dev/vda` |

### Testing a rebuild in a VM

`vm-test.json` exists so the bootstrap can be rehearsed without touching real
hardware. The repository is public, so the guest can fetch it directly from the
Arch ISO.

The full procedure — creating the VM, both bootstrap phases, snapshots,
iterating on a failure, teardown — is in
[`docs/rebuild-rehearsal.md`](../../docs/rebuild-rehearsal.md). How this profile
was adapted from `urakara.json` is under [vm-test.json](#vm-testjson) below.

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

## vm-test.json

`vm-test.json` is a worked example of that adaptation. It differs from
`urakara.json` in exactly four values — everything else, including the
subvolume layout and the Timeshift snapshot config, is identical:

| field | urakara | vm-test |
|---|---|---|
| `hostname` | `urakara` | `dots-test` |
| `...device` | `/dev/nvme0n1` | `/dev/vda` |
| `...partitions[1].size.value` | `999128301568` | `63345524736` |
| `...partitions[].obj_id` | (this laptop's) | regenerated |

The ESP is untouched at 1 MiB start / 1 GiB size; only the root partition
depends on disk size. Sizing leaves 4 MiB at the end of the device for the
GPT secondary header.

The large `mirror_config` block is kept verbatim so this reproduces the original
install exactly. It can be trimmed to the region selection if it becomes noisy.
