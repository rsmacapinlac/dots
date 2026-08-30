# Testing the build scripts

The workstation phase runs around 30 steps, most of which only ever execute on a fresh machine. Bugs there are invisible on a working system. A disposable VM is the only way to exercise that path.

`setup/archinstall/vm-test.json` targets a 60 GiB virtio disk and is structurally identical to the real machine's profile apart from the device, disk size and hostname.

## Creating the VM

```bash
# The ISO is ~1.5 GB — keep it outside the repo
curl -o /tmp/archlinux-x86_64.iso \
  https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

virt-install --connect qemu:///system \
  --name dots-test --memory 4096 --vcpus 4 --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/dots-test.qcow2,size=60,bus=virtio,format=qcow2 \
  --boot uefi --cdrom /tmp/archlinux-x86_64.iso --os-variant archlinux \
  --graphics spice --video virtio
```

4096 is enough for ```--memory```.

```
kernel: CPU 3/KVM invoked oom-killer
kernel: Out of memory: Killed process (qemu-system-x86) anon-rss:7283352kB
```
`--boot uefi` matters: `/boot` is an ESP, and a BIOS guest exercises a different
path. `--cpu host-passthrough` exposes VMX so the virtualization steps actually
run. `virt-viewer` must be installed for a usable console.

The VM lives on the system connection, not the session one. Export this or every
`virsh` call needs `--connect qemu:///system`:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```

## Running it

Type the bootstrap **at the VM console**.

```bash
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
```

In the archinstall menu you **must** set a root password and add a user **with sudo/wheel** — the profile deliberately carries no credentials.

## Snapshot before bootstrapping

Reverting takes seconds; reinstalling takes an hour. Do this after archinstall finishes and before running the workstation phase.

Install `qemu-guest-agent` before taking the snapshot, so every revert lands on
a system the host can already inspect. It is **test instrumentation only** —
never part of a real rebuild, and deliberately not in `setup/arch.sh` — but
baking it into the baseline saves reinstalling it by hand after every revert.

```bash
virsh destroy dots-test                              # the ISO ignores ACPI shutdown
virsh change-media dots-test sda --eject --config    # or it boots the installer again
virsh start dots-test
```

Then, at the guest console, log in and install the agent:

```bash
sudo pacman -Sy --noconfirm qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

`systemctl` warns that the unit has no install config; that is expected, since
it is udev-activated. Confirm it came up with `guest-ping` from the host, then
snapshot:

```bash
virsh qemu-agent-command dots-test '{"execute":"guest-ping"}'   # => {"return":{}}

virsh destroy dots-test
virsh snapshot-create-as dots-test clean-install "post-archinstall, agent, pre-bootstrap"
virsh start dots-test

# after a failed attempt
virsh snapshot-revert dots-test clean-install
```

Eject while the domain is stopped. `--config` alone edits the persistent
definition and leaves a running domain untouched.

Because the snapshot is taken with the domain shut off, a revert boots with an
empty `/run` and therefore no cached sudo credential, so `check_sudo` prompts
for real. That only stops being true if the agent is installed in the *same*
session as the bootstrap: `sudo` caches a credential for five minutes, which
silently satisfies `check_sudo` and leaves its password prompt untested. Run
`sudo -k` first in that case.

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

Note that `raw.githubusercontent.com` caches for around five minutes, so a freshly pushed commit is not immediately visible to the guest. The GitHub API serves the current content without that delay:

```bash
curl -fsSL -H 'Accept: application/vnd.github.raw' -o /tmp/start.sh \
  'https://api.github.com/repos/rsmacapinlac/dots/contents/setup/start.sh?ref=main'
```

## Driving it from the host

The console can be operated without touching the VM window, which is useful for scripted or unattended rehearsals.

```bash
virsh screenshot dots-test /tmp/console.png          # read the screen
virsh send-key dots-test --codeset linux KEY_ENTER   # type at the console
```

`send-key` takes one keycode per call, so typing a long command is tedious but scriptable. The Arch ISO also runs `qemu-guest-agent`, so commands can be run in the *live* environment directly — handy for staging files before typing:

```bash
virsh qemu-agent-command dots-test \
  '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","..."],"capture-output":true}}'
```

That only works on the ISO. The installed system has no guest agent of its own,
so without one the console is the only way in after the first reboot — which
makes diagnosing a failure 25 steps into the workstation phase painful, since a
framebuffer screenshot shows about 25 lines at a time. Installing it into the
baseline is covered in [Snapshot before bootstrapping](#snapshot-before-bootstrapping).

With the agent running, the console can be read as text rather than pixels,
which beats cropping screenshots:

```bash
virsh qemu-agent-command dots-test \
  '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","fold -w 160 /dev/vcs1"],"capture-output":true}}'
```

Note that the agent runs as root and bypasses the console entirely, so use it to
*verify* results, never to drive `start.sh` — driving it from anywhere but the
console is what hides terminal-handling bugs.

## What a VM will not tell you

Hyprland and greetd do come up on software rendering, but a VM has no real GPU,
so failures there usually mean the VM rather than the configuration. `battery`
is absent, which is worth knowing: it is why waybar's volume pill was found
rendering with a flat edge. `install_steam` is a large download worth skipping on
a first pass. Budget 45-90 minutes for a full run.

## Tearing it down

```bash
virsh destroy dots-test
virsh undefine dots-test --nvram --remove-all-storage \
  --snapshots-metadata                                 # --nvram: the VM is UEFI
```

`--snapshots-metadata` is required once `clean-install` exists; without it
`undefine` refuses with "cannot delete inactive domain with 1 snapshots".

## See also

- [`setup/archinstall/README.md`](../setup/archinstall/README.md) — how
  `vm-test.json` was derived from the real machine's profile, and which values
  are hardware-bound.
