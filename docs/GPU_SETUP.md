# GPU Setup — RTX 5060 Laptop (GB206M, Blackwell)

The dGPU in this machine is a **GB206M**: Blackwell, compute capability
`sm_120`, PCI ID `01:00.0`. Two facts drive everything on this page.

1. **There is no closed-source driver for GB206M.** `nvidia-dkms`, the
   proprietary kernel module, has no build for this part. The old archloq
   script installed it; installing it produces nothing usable.
2. **`nvidia-open` is the only driver.** In Arch it ships as
   `nvidia-open-dkms`, and it requires the GSP-RM firmware path, which cannot
   be disabled.

This document describes what `install-scripts/app/02_gpu_nvidia.sh` and
`config/loq.conf` actually install. `nvidia-dkms` and `optimus-manager` appear
here only in §10, to record why they are gone.

---

## 1. Hardware as measured

From `docs/REFORMAT-XFCE.md` §2, taken from the outgoing Omarchy install:

| Item | Value |
|------|-------|
| dGPU | `01:00.0` NVIDIA GB206M [GeForce RTX 5060 Max-Q / Mobile], rev a1 |
| iGPU | `00:02.0` Intel Raptor Lake-S UHD, rev 04 → `i915` |
| `boot_vga` | 0 (Intel) |
| DRM cards | `card0` = i915, `card1` = nvidia |
| Outputs | `card1` exposes `DP-1/2/3` and `HDMI-A-1/2/3` |
| Driver version observed | `nvidia-open-dkms` 610.57.04-1 |

**The external outputs are wired to the dGPU.** This is the single most
important consequence for day-to-day use and it is covered in §5.

Verify the layout on your own machine at any time:

```bash
lspci -nnk -d '10de:' | grep -A3 -i vga
cat /sys/class/drm/card*/device/uevent | grep -E 'DRIVER|PCI_SLOT_NAME'
```

---

## 2. Packages

`config/loq.conf`, single source of truth:

```bash
LOQ_NVIDIA_PACKAGES="nvidia-open-dkms nvidia-utils nvidia-settings nvidia-prime lib32-nvidia-utils libva-nvidia-driver"
LOQ_GPU_MODE="hybrid"          # hybrid | integrated | nvidia
LOQ_ENABLE_NVIDIA_RTD3="1"
```

| Package | Why |
|---------|-----|
| `nvidia-open-dkms` | the Blackwell kernel module, built per kernel by DKMS |
| `nvidia-utils` | `nvidia-smi`, `nvidia-settings`, `nvidia-persistenced`, the GL/EGL/Vulkan ICDs |
| `nvidia-settings` | the GUI control panel |
| `nvidia-prime` | `prime-run` and the PRIME profiles |
| `lib32-nvidia-utils` | 32-bit ICDs for Steam/Proton titles |
| `libva-nvidia-driver` | hardware video decode/encode through VA-API |

Also written by `02_gpu_nvidia.sh` (not from `loq.conf`):

- `envycontrol` from the AUR, for mode switching (§5). If it cannot be built
  the script warns and continues; the driver still works in `hybrid`.
- `power-profiles-daemon`, enabled, because envycontrol talks to it when it
  changes GPU mode. See [POWER_MANAGEMENT.md](POWER_MANAGEMENT.md).

To install or re-run just this step:

```bash
sudo install-scripts/app/02_gpu_nvidia.sh
```

`02_gpu_nvidia.sh` refuses to continue if `nvidia-dkms` or `nvidia` is
installed, and `90_postinstall.sh` reports either as a problem.

---

## 3. DKMS rebuilds on every kernel bump

The module is not in a binary package: it is compiled by DKMS against the
running kernel's headers. `02_gpu_nvidia.sh` installs `<kernel>-headers` for
every `/usr/lib/modules/*/build` directory it finds, so the build succeeds for
whichever kernels are present, not only `linux-zen`.

Every kernel update therefore recompiles the driver, and a failure there takes
the display with it. Check that it built for the kernel you are running:

```bash
modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1 && echo "built for $(uname -r)" || echo "NOT built for $(uname -r)"
```

If it did not build, the pacman transaction left DKMS behind:

```bash
sudo dkms autoinstall
sudo mkinitcpio -P
sudo reboot
```

`99_safe_reboot_check.sh` performs this check before it will let you reboot, and
treats a missing module as a warning rather than a blocker — before the first
reboot there is no running kernel to build against yet.

Previous modules are kept per kernel under `/var/cache/dkms`, which is what
makes the rollback in §9 possible. Snapshoting is not an alternative here:
`/boot` is FAT32 and is not covered by btrfs-assistant, so a timeshift rollback
does **not** roll back the kernel. See [RECOVERY.md](RECOVERY.md).

---

## 4. Module options

Two files. `02_gpu_nvidia.sh` writes the NVIDIA one on every run; the platform
one is static and installed from the repo.

`/etc/modprobe.d/nvidia.conf`, written by `02_gpu_nvidia.sh`:

```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_DynamicPowerManagement=0x02 NVreg_PreserveVideoMemoryAllocations=1
```

| Option | Effect | Consequence of getting it wrong |
|--------|--------|-----------------------------------|
| `modeset=1` | `nvidia_drm` performs KMS mode setting on the NVIDIA GPU | **Required.** Without it `nvidia_drm` does not do KMS and the display manager cannot set a mode on the dGPU. In `nvidia` mode you get a black screen, and `nvidia-smi` still works, so it looks like a driver problem when it is not. |
| `fbdev=1` | exposes the legacy `/dev/fb0` framebuffer interface | Needed by anything that writes to the framebuffer directly. Cheap. |
| `NVreg_DynamicPowerManagement=0x02` | fine-grained PCI Express Runtime D3 | What actually lets the dGPU drop to a low-power state while idle. `0x00` disables runtime PM entirely; `0x01` is the coarse whole-device D3 variant, which saves little and is a known source of suspend/resume trouble. Requires Turing or later — GB206M qualifies. |
| `NVreg_PreserveVideoMemoryAllocations=1` | keeps VRAM contents allocated across suspend | Sidesteps the resume-time reallocation failure that shows up as a corrupted or black desktop after waking. Costs the VRAM back while suspended. |

`LOQ_ENABLE_NVIDIA_RTD3="0"` removes the `NVreg_DynamicPowerManagement=0x02`
token from the file with `sed -i` and tells you the dGPU will draw more idle
power. It does not touch the other three options.

`/etc/modprobe.d/lenovo-loq.conf`, installed verbatim from
`config/modprobe.d/lenovo-loq.conf`:

| Option | Effect |
|--------|--------|
| `options i915 enable_fbc=1` | iGPU framebuffer compression; saves power and is needed for VA-API on the Intel side |
| `options snd_hda_intel power_save=1 power_save_controller=Y` | codec power saving on the HDA audio controller; measurably reduces idle draw on this platform |
| `options usbcore autosuspend=-1` | no autosuspend by default; input stability and Bluetooth reliability are worth more than the small idle gain |

### GSP firmware is mandatory

On `nvidia-open` the GPU runs its work through GSP-RM firmware loaded by the
driver. **`NVreg_EnableGpuFirmware=0` does not exist on this driver.** That
parameter came from the closed-driver era and is folklore now. If you find it in
an old `/etc/modprobe.d/nvidia.conf` or a wiki snippet, delete it: with
`nvidia-open` it is at best ignored and at worst produces a driver that loads
and then fails to initialise the GPU.

`02_gpu_nvidia.sh` will not write it. Neither should you.

### What was removed from this file

Two lines that used to live here are gone, both from
`docs/REFORMAT-XFCE.md` §21:

- `options i915 enable_guc=2` — the `enable_guc` parameter was removed from the
  kernel years ago; setting it produces an "unknown parameter" warning and no
  behaviour.
- `options legion-laptop force=1` — the `legion_laptop` module is superseded by
  LenovoLegionLinux (`legiond`). Forcing both is how two daemons end up fighting
  over the embedded controller. Legion behaviour is configured through
  `config/legiond/legiond.ini`; see [FAN_CONTROL.md](FAN_CONTROL.md).

### initramfs

Both `01_kernel_boot.sh` and `02_gpu_nvidia.sh` write
`/etc/mkinitcpio.conf.d/nvidia.conf`:

```
install_modules+=" nvidia nvidia_drm nvidia_modeset nvidia_uvm "
```

The modules must be in the initramfs: early userspace needs the GPU for the
display manager's mode setting and for suspend/resume. `02_gpu_nvidia.sh` runs
`mkinitcpio -P` at the end regardless of whether the kernel changed, because the
drop-in itself is new.

---

## 5. envycontrol: the three modes

`envycontrol` drives the PRIME profiles. It is explicitly documented as
compatible with both SDDM and LightDM; `LOQ_DISPLAY_MANAGER="sddm"` is the
default in `config/loq.conf`, and `05_desktop_xfce.sh` installs SDDM
specifically because envycontrol rewrites its `Xsetup` script to inject the
PRIME profile.

| Mode | Command | Internal panel | External HDMI/DP | Use for |
|------|---------|----------------|------------------|---------|
| `hybrid` | `envycontrol -s hybrid` | i915 | nvidia | the default; everything works, dGPU idles via RTD3 |
| `integrated` | `envycontrol -s integrated` | i915 | **dark** | battery, internal panel only |
| `nvidia` | `envycontrol -s nvidia` | nvidia | nvidia | plugged in, external display, G-Sync |

**`integrated` cannot drive an external monitor on this chassis.** `card1`
exposes `DP-1/2/3` and `HDMI-A-1/2/3`: the outputs are wired to the dGPU, not
switched through the iGPU. `02_gpu_nvidia.sh` prints exactly this warning before
switching:

```
integrated mode: external monitors will be dark on this laptop (outputs are dGPU-wired)
```

So `integrated` is a battery-only mode for use with the internal panel and
nothing attached. For anything else, `hybrid`.

Note the mode names are `integrated` / `hybrid` / `nvidia`. There is no
`discrete`, and there is no `enjoycontrol-gpu-switch` command; both appeared in
the previous version of this document and were wrong.

`LOQ_GPU_MODE` is applied once at install time by `02_gpu_nvidia.sh`. For it to
be re-applied at every boot, envycontrol's own systemd unit has to be enabled;
the script says so when `LOQ_GPU_MODE` is not `hybrid`. Check the live mode:

```bash
envycontrol -g
systemctl status envycontrol --no-pager
```

### Runtime toggles: `--rtd3` and `--force-comp`

envycontrol also exposes two runtime toggles. **Neither is called by this repo**:
`02_gpu_nvidia.sh` only ever runs `envycontrol -s <mode>` and tells you to run
`envycontrol -g`.

| Flag | What it does | Why this repo does not use it |
|------|--------------|------------------------------|
| `--rtd3` | toggles Runtime D3 for the dGPU at runtime (sets `power/control` to `auto` and adjusts `NVreg_DynamicPowerManagement`) | the authoritative value in this setup lives in `/etc/modprobe.d/nvidia.conf`. Driving it from two places is how you end up with a mode that differs between reboots and does not survive the next `pacman -Syu`. Set it in `LOQ_ENABLE_NVIDIA_RTD3` instead. |
| `--force-comp` | forces X compositing through the NVIDIA GPU | only meaningful in `nvidia` mode, where the dGPU already owns the display. In `hybrid` it undoes the point of hybrid mode. xfwm4's built-in compositor is used; no external compositor is installed. |

Both are interactive and prompt for confirmation, which is a further reason the
install scripts do not call them. Flag availability depends on the envycontrol
version you have from the AUR — run `envycontrol --help` to see what your build
offers before relying on either.

---

## 6. Why supergfxctl is not used

`supergfxctl` is the other popular MUX switcher for this class of laptop, and it
is deliberately absent here. Its own wiki advises against installing it during
the transition to its successor (`cardwire`), **unless you need VFIO**. There is
no VFIO passthrough in this setup and nothing here asks for one.

`envycontrol` covers the three modes this machine actually needs and is
compatible with the chosen display manager. Adding a second MUX tool would mean
two things writing the same PRIME sysctl profiles.

`optimus-manager` and `bumblebee` are also not used: unmaintained, or
incompatible with `nvidia-open`. See §10.

---

## 7. Verification

After the first boot, in this order:

```bash
nvidia-smi
nvidia-smi -L
modinfo -k "$(uname -r)" nvidia | head -3
lsmod | grep -E '^nvidia'
cat /sys/module/nvidia_drm/parameters/modeset
envycontrol -g
```

Expected: `nvidia-smi` reports a driver version and the GB206M; `modeset`
prints `Y`; `envycontrol -g` reports `hybrid`.

`90_postinstall.sh` runs the same checks (`nvidia-open-dkms` present,
`nvidia-dkms`/`nvidia` absent, `nvidia-smi -L`, `modeset = Y`):

```bash
sudo install-scripts/pacmaster.sh --audit
```

---

## 8. Troubleshooting

### Black screen, but `nvidia-smi` works

That combination means the module loaded and the display did not. Check modeset
first — it is the parameter that produces exactly this symptom.

```bash
cat /sys/module/nvidia_drm/parameters/modeset
cat /proc/cmdline
```

If it is `N`, or if `nvidia_drm.modeset=1` is missing from `/proc/cmdline`:

```bash
sudo mkdir -p /etc/kernel/cmdline.d
printf 'nvidia_drm.modeset=1\n' | sudo tee /etc/kernel/cmdline.d/10-nvidia-modeset.conf
sudo kernel-install add-all "$(uname -r)"
sudo reboot
```

Other things to read while you are in there:

```bash
journalctl -b -k --no-pager | grep -iE 'nvidia|drm|gsp' | tail -40
journalctl -b --no-pager -u sddm | tail -40
```

### Boot into the iGPU only, as a diagnostic

Add `nvidia_drm.modeset=0` to the kernel command line. `nvidia_drm` then never
registers as a display device, which forces the internal panel onto `i915` and
is enough to prove whether a failure is the dGPU or the rest of the stack.
Remove it once you have an answer.

```bash
sudo mkdir -p /etc/kernel/cmdline.d
printf 'nvidia_drm.modeset=0\n' | sudo tee /etc/kernel/cmdline.d/10-force-igpu.conf
sudo kernel-install add-all "$(uname -r)"
sudo reboot
```

To undo:

```bash
sudo rm -f /etc/kernel/cmdline.d/10-force-igpu.conf
sudo kernel-install add-all "$(uname -r)"
sudo reboot
```

### dGPU will not idle

`RTD3` is the cause nine times out of ten. Confirm the parameter reached the
module:

```bash
cat /sys/module/nvidia/parameters/NVreg_DynamicPowerManagement 2>/dev/null
for d in /sys/bus/pci/devices/0000:01:00.*; do printf '%s control=%s status=%s\n' "$d" "$(cat "$d/power/control")" "$(cat "$d/power/runtime_status")"; done
```

`control=auto` with `status=suspended` when nothing is rendering is the healthy
state. If `status=active` while idle, find what is holding the device open:

```bash
sudo fuser -v /dev/nvidia* 2>&1
```

### Rolling back the driver or the kernel

DKMS keeps the previously built modules, and systemd-boot keeps the previous
entries until you prune them, so you have two independent ways back:

```bash
bootctl list
```

Boot the older entry from the firmware menu, then, once you are up:

```bash
ls -1 /var/cache/pacman/pkg/linux-zen-*.pkg.tar.zst
sudo pacman -U /var/cache/pacman/pkg/linux-zen-<previous-version>.pkg.tar.zst
sudo mkinitcpio -P
sudo reboot
```

If `pacman -U` on the kernel does not rebuild the driver, force it:

```bash
sudo pacman -U /var/cache/pacman/pkg/linux-zen-<previous-version>.pkg.tar.zst
sudo dkms autoinstall -k "$(uname -r)"
sudo mkinitcpio -P
```

The full runbook, including "the ESP is fine but nothing boots", is in
[RECOVERY.md](RECOVERY.md). Do not duplicate it here.

---

## 9. What to expect, and what not to expect

| Claim | Status |
|-------|--------|
| `hybrid` idles the dGPU with RTD3 enabled | Depends on `LOQ_ENABLE_NVIDIA_RTD3="1"` and on nothing holding a `/dev/nvidia*` handle open |
| `integrated` drives an external monitor | **No.** Outputs are dGPU-wired |
| `nvidia` mode drives both panel and external outputs | Yes; costs the battery |
| VA-API works for video decode | Through `libva-nvidia-driver` for the NVIDIA path, `i915` for the Intel path — pick one, do not expect both at once |
| Wayland | Not in scope. `LOQ_DISPLAY_MANAGER="sddm"` with Xfce/xfwm4 is an X11 session; Wayland NVIDIA offload is a separate problem this setup does not solve |

---

## 10. What changed from the previous version of this document

| Before | Now | Why |
|--------|-----|-----|
| `yay -S nvidia-dkms nvidia-utils-dkms cuda-dkms` | `nvidia-open-dkms` and the rest of `LOQ_NVIDIA_PACKAGES` | `nvidia-dkms` has no build for GB206M. It installed nothing usable. |
| CUDA / PyTorch nightly cu128 instructions | removed | This is a development workstation with no LLM stack by decision (`LOQ_ENABLE_OLLAMA` etc. are gone). `nvidia-utils` still provides `nvidia-smi`; install CUDA deliberately if you ever want it. |
| `enjoycontrol-gpu-switch hybrid\|integrated\|discrete` | `envycontrol -s hybrid\|integrated\|nvidia` | Wrong command name, and `discrete` is not an envycontrol mode |
| `loq-control` GUI in `runtime/loq-control` | removed | `runtime/` contains only `README.md` and `fetch-runtime.sh`. That GUI did not exist in the repo. |
| Kernel parameter added to `/etc/kernel/cmdline` and UKI rebuilt | `options nvidia_drm modeset=1` in `/etc/modprobe.d/nvidia.conf` | There is no UKI here — the kernel is `linux-zen` on `systemd-boot` with an initramfs. The drop-in is the right place and is written by `02_gpu_nvidia.sh`. |
| `nvidia_drm.modeset=1` listed as an nvidia.conf option and as a kernel parameter | modprobe drop-in only | Two sources for one setting is how they drift apart |
| No mention of GSP firmware | stated as mandatory | Prevents someone reintroducing `NVreg_EnableGpuFirmware=0` from a wiki snippet |
| "NVIDIA offload not supported on Wayland" | scoped to the session type actually used | Xfce + xfwm4 + SDDM is an X11 session. The Wayland question is real but not this setup's problem. |

`optimus-manager` was never used and is not used now: it is unmaintained and
does not support `nvidia-open`. See §6.