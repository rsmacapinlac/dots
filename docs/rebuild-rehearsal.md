# Rehearsing a rebuild

The workstation phase runs around 30 steps, most of which only ever execute on a
fresh machine. Bugs there are invisible on a working system — the ones found so
far were a missing `base-devel`, a stale `PATH`, and a package that cannot be
installed unattended at all, none of which can reproduce on a machine that
already works. A disposable VM is the only way to exercise that path.

`setup/archinstall/vm-test.json` targets a 60 GiB virtio disk and is
structurally identical to the real machine's profile apart from the device, disk
size and hostname.

## Creating the VM

```bash
# The ISO is ~1.5 GB — keep it outside the repo
curl -o ~/Downloads/archlinux-x86_64.iso \
  https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

virt-install --connect qemu:///system \
  --name dots-test --memory 4096 --vcpus 4 --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/dots-test.qcow2,size=60,bus=virtio,format=qcow2 \
  --boot uefi --cdrom ~/Downloads/archlinux-x86_64.iso --os-variant archlinux \
  --graphics spice --video virtio
```

Size `--memory` against the **host**, not the guest's appetite. 8192 on a
16 GB laptop that is also running a desktop had the host OOM-killer take out
qemu mid-install:

```
kernel: CPU 3/KVM invoked oom-killer
kernel: Out of memory: Killed process (qemu-system-x86) anon-rss:7283352kB
```

4096 is enough for the install and the AUR builds.

`--boot uefi` matters: `/boot` is an ESP, and a BIOS guest exercises a different
path. `--cpu host-passthrough` exposes VMX so the virtualization steps actually
run. `virt-viewer` must be installed for a usable console.

The VM lives on the system connection, not the session one. Export this or every
`virsh` call needs `--connect qemu:///system`:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```

## Running it

Type the bootstrap **at the VM console**, not over SSH. A real rebuild has no
SSH, and two of the bugs found so far were terminal handling that SSH would have
hidden — a piped script whose stdin swallowed its own text, and a TUI that drew
correctly but ignored every keypress.

```bash
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
```

The same command runs at both phases. On the ISO it lists profiles, confirms the
target disk, and runs archinstall; after a reboot it builds the workstation.

In the archinstall menu you must set a root password and add a user **with
sudo/wheel** — the profile deliberately carries no credentials, and the
workstation phase fails at `check_sudo` without them.

If `start.sh` itself is what is broken, the install phase can be driven
directly from the ISO — this is the path `start.sh` automates:

```bash
curl -fsSL -o /tmp/vm.json \
  https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/archinstall/vm-test.json
archinstall --config /tmp/vm.json
```

## Snapshot before bootstrapping

Reverting takes seconds; reinstalling takes an hour. Do this after archinstall
finishes and before running the workstation phase.

```bash
virsh destroy dots-test                              # the ISO ignores ACPI shutdown
virsh change-media dots-test sda --eject --config    # or it boots the installer again
virsh snapshot-create-as dots-test clean-install "post-archinstall, pre-bootstrap"
virsh start dots-test

# after a failed attempt
virsh snapshot-revert dots-test clean-install
```

Eject while the domain is stopped. `--config` alone edits the persistent
definition and leaves a running domain untouched.

## Iterating on a failure

Test a branch without merging to `main`:

```bash
DOTS_REF=my-branch bash -c 'curl -fsSL \
  https://raw.githubusercontent.com/rsmacapinlac/dots/my-branch/setup/start.sh | bash'
```

Re-run a single failing step rather than the whole script — `setup/arch.sh`
skips `main()` when sourced, which is what its `BASH_SOURCE` guard is for:

```bash
source ~/workspace/dots/setup/arch.sh   # defines functions, runs nothing
install_hyprland                        # just the step that failed
```

Note that `raw.githubusercontent.com` caches for around five minutes, so a
freshly pushed commit is not immediately visible to the guest. The GitHub API
serves the current content without that delay:

```bash
curl -fsSL -H 'Accept: application/vnd.github.raw' -o /tmp/start.sh \
  'https://api.github.com/repos/rsmacapinlac/dots/contents/setup/start.sh?ref=main'
```

## Driving it from the host

The console can be operated without touching the VM window, which is useful for
scripted or unattended rehearsals.

```bash
virsh screenshot dots-test /tmp/console.png          # read the screen
virsh send-key dots-test --codeset linux KEY_ENTER   # type at the console
```

`send-key` takes one keycode per call, so typing a long command is tedious but
scriptable. The Arch ISO also runs `qemu-guest-agent`, so commands can be run in
the *live* environment directly — handy for staging files before typing:

```bash
virsh qemu-agent-command dots-test \
  '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","..."],"capture-output":true}}'
```

That only works on the ISO. The installed system has no guest agent until
something installs and enables one, so after the first reboot the console is the
only way in.

## What a VM will not tell you

Hyprland and greetd do come up on software rendering, but a VM has no real GPU,
so failures there usually mean the VM rather than the configuration. `battery`
is absent, which is worth knowing: it is why waybar's volume pill was found
rendering with a flat edge. `install_steam` is a large download worth skipping on
a first pass. Budget 45-90 minutes for a full run.

## Tearing it down

```bash
virsh destroy dots-test
virsh undefine dots-test --nvram --remove-all-storage   # --nvram: the VM is UEFI
```

## See also

- [`setup/archinstall/README.md`](../setup/archinstall/README.md) — how
  `vm-test.json` was derived from the real machine's profile, and which values
  are hardware-bound.
