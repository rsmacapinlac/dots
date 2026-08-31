# Testing the build scripts

The rebuild has a live-ISO Archinstall phase, a post-reboot core phase, and
optional application groups installed from the finished Hyprland desktop. Many
core steps only execute on a fresh machine, so a disposable VM is the only way
to exercise the complete path.

`setup/archinstall/vm-test.json` targets a 30 GiB virtio disk and is structurally identical to the real machine's profile apart from the device, disk size and hostname.

30 GiB is sized from a measured run, not guessed: the core phase uses about
6 GB, and `applications.sh all` takes it to **16 GB** — and that figure is
optimistic, since it was measured with a freshly cleared package cache and
before Timeshift snapshots had accumulated. Leave headroom for both, plus the
slack btrfs wants to avoid behaving badly when near-full.

**Changing the size means changing two things.** The `--disk size=` below and
`partitions[1].size.value` in `vm-test.json` must agree, or Archinstall tries to
create a partition larger than the disk and fails at partitioning. The profile
value is the disk size minus the 1 GiB ESP start offset (`1074790400`) minus
4 MiB for the GPT backup header — for 30 GiB that is `31133270016`.

You *must*:
- Test as if you're the user. Send keys to the virtual machine as a user would with a keyboard.
- Show the virtual machine using the viewer, so the work can be monitored by a human.

## Creating the VM

```bash
# The ISO is ~1.5 GB — keep it outside the repo
curl -o /tmp/archlinux-x86_64.iso \
  https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Verify it. A truncated or corrupt ISO wastes a full rehearsal before it fails.
curl -fsSL -o /tmp/sha256sums.txt \
  https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt
grep 'archlinux-x86_64.iso$' /tmp/sha256sums.txt \
  | sed 's#archlinux-x86_64.iso#/tmp/archlinux-x86_64.iso#' | sha256sum -c -

virt-install --connect qemu:///system \
  --name dots-test --memory 4096 --vcpus 4 --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/dots-test.qcow2,size=30,bus=virtio,format=qcow2 \
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

## Snapshot before the core phase

Install `qemu-guest-agent` before taking the snapshot. 

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

`systemctl` warns that the unit has no install config; that is expected, since it is udev-activated. Confirm it came up with `guest-ping` from the host, then snapshot:

> **Check the unit file, not just `guest-ping`.** Because the agent is
> udev-activated, `qemu-ga` can be running while its systemd unit is unusable —
> so `guest-ping` succeeds and the agent still disappears after the core phase's
> daemon-reloads and the next reboot. This has happened: a corrupt download left
> `/usr/lib/systemd/system/qemu-guest-agent.service` at **0 bytes**, which
> systemd treats as *masked*. Verify both:
>
> ```bash
> test -s /usr/lib/systemd/system/qemu-guest-agent.service && echo unit-ok
> systemctl is-active qemu-guest-agent          # expect: active
> ```
>
> If the unit is empty, the cached package is corrupt. Clear it and reinstall:
>
> ```bash
> sudo find /var/cache/pacman/pkg -name '*.pkg.tar.zst' -delete
> sudo pacman -Sy --noconfirm --overwrite '/usr/*' qemu-guest-agent
> ```

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

## Testing a branch

Test a branch without merging to `main`:

```bash
DOTS_REF=my-branch bash -c 'curl -fsSL \
  https://raw.githubusercontent.com/rsmacapinlac/dots/my-branch/setup/start.sh | bash'
```

Both provisioning scripts are idempotent. After correcting a failure, rerun the
whole relevant entry point: `setup/start.sh` for core provisioning or
`setup/applications.sh <group>` for an optional group. There is intentionally no
public single-function recovery interface.

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
makes diagnosing a late core failure painful, since a framebuffer screenshot
shows about 25 lines at a time. Installing it into the baseline is covered in
[Snapshot before the core phase](#snapshot-before-the-core-phase).

With the agent running, the console can be read as text rather than pixels,
which beats cropping screenshots:

```bash
virsh qemu-agent-command dots-test \
  '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","fold -w 160 /dev/vcs1"],"capture-output":true}}'
```

Note that the agent runs as root and bypasses the console entirely, so use it to
*verify* results, never to drive `start.sh` — driving it from anywhere but the
console is what hides terminal-handling bugs.

## Verify the desktop and optional installer

After the core phase succeeds, reboot and confirm greetd starts Hyprland for the
user. Run the checks in [`arch-vm-validation.md`](arch-vm-validation.md), then
exercise the optional interface without installing everything at once:

```bash
setup/applications.sh --help
setup/applications.sh media mail
```

Run `setup/applications.sh` with no arguments to verify the fzf multi-select
menu and cancellation path. Each invocation must perform one full system
upgrade, install the selected packages, and enable only services owned by those
groups.

## What a VM will not tell you

Hyprland and greetd do come up on software rendering, but a VM has no real GPU,
so failures there usually mean the VM rather than the configuration. `battery`
is absent, which is worth knowing when checking Waybar styling. Hardware checks
must remain vendor-neutral. Steam and virtualization are optional, large
downloads and should be validated separately from the core rehearsal.

**EGL does not work in this VM, and that has teeth.** `eglInitialize` fails
(`EGL_NOT_INITIALIZED`, `DRI2: failed to create screen`), Mesa falls back to
`kms_swrast`, and that fallback wants DRM dumb buffers on the card instead of
the render node — which the compositor already holds as DRM master. Anything
using EGL therefore dies with `DRM_IOCTL_MODE_CREATE_DUMB failed: Permission
denied`. `hyprpaper` is the visible casualty: it exits, and the session falls
back to Hyprland's built-in background.

Three graphics configurations were tried, and all fail the same way. Do not
spend time on this again:

| Config | Result |
|---|---|
| No acceleration (the `virt-install` above) | EGL fails immediately; `hyprpaper` never starts |
| `--video ...accel3d=yes` + `--graphics egl-headless` | `hyprpaper` starts, dies on render |
| spice GL + virgl as the sole GL display | `hyprpaper` starts, dies on render |

The signature is precise and identical each time:

```
hyprctl hyprpaper listactive   → ipc=0                    # healthy
set_wallpaper --initial        → exit 0                   # "succeeds"
hyprctl hyprpaper listactive   → wire handshake failed    # now dead
```

`hyprpaper` idles happily and dies the moment it has to *render* an image, on
GBM buffer allocation. Ruled out along the way, each by direct check rather
than inference:

- **Environment** — uwsm finalizes correctly; `systemctl --user show-environment`
  carries `WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE` and friends.
- **Permissions** — `getfacl /dev/dri/card*` shows the logind seat ACL granting
  the user `rw`.
- **A startup race** — it dies even when `hyprpaper` is fully up and answering
  IPC first.

Notes if you try anyway: spice GL needs a *local socket* listen, which
disconnects `virt-viewer` (`spice://127.0.0.1:5900` stops working) — revert
`<listen type='address'/>` to get the viewer back. QEMU also refuses more than
one OpenGL display, so `egl-headless` and spice GL are mutually exclusive.

So: **wallpaper and any other GPU-dependent behaviour cannot be validated in
this VM.** Verify those on real hardware, and do not record a VM failure of
that kind as a configuration defect.

Unrelated to the GPU and worth fixing on its own: `set_wallpaper` returns exit
0 when the IPC wait loop times out, so a dead `hyprpaper` produces no wallpaper
and no error.

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
