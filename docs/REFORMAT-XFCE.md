# REFORMAT-XFCE — Arch Linux from scratch on Lenovo LOQ 17IRX10

Status: **proposed, awaiting approval.** Nothing in this document has been executed.
Every destructive step is gated on explicit human approval.

Date: 2026-10-08 · Scope: replace Omarchy 4.0.4 with plain Arch + Xfce, driven from this repo.

---

## 1. Frozen decisions

| # | Decision | Value |
|---|----------|-------|
| 1 | Canonical repo | `archloq`. `archlegion` is archived; reusable pieces are ported in. |
| 2 | Install method | `archinstall` **minimal** (base + kernel + partitions + bootloader). Everything else from repo scripts. |
| 3 | Disk | LUKS2 + **four partitions** (ESP / swap / root / home), btrfs subvolumes + snapshots (timeshift + btrfs-assistant). |
| 4 | GPU | `nvidia-open-dkms` + `envycontrol` (integrated / hybrid / nvidia, RTD3). |
| 5 | Power | `power-profiles-daemon` + `legiond` + `thermald`. **No TLP.** |
| 6 | Desktop | Xfce, tunable but sober: xfwm4 native compositor, no picom, Catppuccin Mocha. |
| 7 | Kernel / boot | `linux-zen` + `systemd-boot`. Secure Boot **disabled**. |
| 8 | Software | Dev stack, **no LLM stack** (no ollama / llama.cpp / open-webui). |
| 9 | Dotfiles | Recycle DE-agnostic parts, replace all Hyprland/KDE pieces with Xfce. |
| 10 | Backup | `EROSBACKUP` (ST1000LM035, ext4) becomes a managed `borg` target. |
| 11 | Undervolt | Conservative values + diagnostics, kill-switched from `loq.conf`. |
| 15 | Swap | Dedicated LUKS swap partition for hibernate, *plus* archinstall-managed zram. |
| 12 | Identity | user `autcir`, hostname `loq`, LUKS2 passphrase + initramfs keyfile. |
| 13 | Hardening | Practical: nftables (SSH), fail2ban, wheel sudo, sysctl hardening. |
| 14 | Snapshots | timeshift on btrfs-assistant: 5 hourly / 4 daily / 3 weekly / 2 monthly. |

---

## 2. Current state (measured, not assumed)

```
OS            Omarchy 4.0.4 (ID=omarchy, ID_LIKE=arch)
kernel        7.2.5-3-omarchy
RAM           31 GiB
CPU           13th Gen Intel Core i7-13700HX, 24 threads (16 cores, Raptor Lake-S)
iGPU          00:02.0 Intel Raptor Lake-S UHD (rev 04)   -> i915
dGPU          01:00.0 NVIDIA GB206M [GeForce RTX 5060 Max-Q / Mobile] (rev a1)
boot_vga      0 (Intel)
drm            card0 = i915, card1 = nvidia
               card1 exposes DP-1/2/3 + HDMI-A-1/2/3  -> external outputs are dGPU-wired
storage        nvme0n1  953.9G  WD PC SN7100S SDFPMSL-1T00-1101
                 p1 2G    vfat    -> /boot
                 p2 951.9G crypto_LUKS -> btrfs (root, subvol @, compress=zstd:3, ssd)
               sdb     931.5G  ST1000LM035-1RK172   sdb1 ext4 -> EROSBACKUP (udisked)
               sda      14.4G   DataTraveler 3.0    sda1 exfat -> Ventoy
               zram0    15.5G   swap (Omarchy-managed)
UEFI           yes
graphics pkgs  nvidia-open-dkms 610.57.04-1, nvidia-utils, nvidia-settings,
               nvidia-prime, lib32-nvidia-utils, libva-nvidia-driver
power pkgs     power-profiles-daemon 0.30-1, thermald 2:2.5.12-1.  No TLP, no legiond.
AUR helper     yay
```

**Consequence of `dGPU-wired external outputs`:** `envycontrol -s integrated` cannot drive an
external monitor on this machine. That mode is only useful on battery with the internal panel.

---

## 3. Defects found in the current repos

These are real, verified, and each one blocks or corrupts an install.

| Repo | File | Defect |
|------|------|--------|
| archloq | `install-scripts/app/01_kernel_nvidia.sh` | Installs `nvidia-dkms` (proprietary). **Does not exist for GB206M.** Blackwell requires `nvidia-open`. Running this script today installs nothing usable. |
| archloq | `docs/INSTALLATION.md` | "Arch from Zero" prescribes unencrypted ext4 + `linux-zen`, no LUKS, no btrfs, no bootloader steps, no ESP GUID. Superseded by this document. |
| archloq | `config/loq.conf` | `LOQ_ENABLE_LEGIOND` declared twice (lines 22 and 37). |
| archloq | `config/loq.conf` + `install-scripts/app/02_power_management.sh` | Enables TLP **and** `power-profiles-daemon` **and** thermald **and** legiond simultaneously. TLP and PPD fight over the same sysfs knobs. |
| archloq | `docs/POWER_MANAGEMENT.md`, `docs/FAN_CONTROL.md` | Written around TLP. Need a PPD-based rewrite. |
| archloq | `dotfiles/config/` | Entirely Hyprland/KDE: `hypr/`, `waybar/`, `rofi/`, `kwin/`, `konsole/`. **Zero X11/Xfce.** |
| archloq | `dotfiles/scripts/05-plasma-widgets.sh`, `06-konsave-backup.sh` | Plasma/KDE-only, dead weight on Xfce. |
| archloq | `install-scripts/install-hyprland.sh` | Omarchy-era leftover. Removed. |
| archlegion | `archinstall/user_configuration.json` | **Has no `disk_config` at all** — it cannot partition anything. |
| archlegion | `archinstall/partition_preset.json` | Stale 2.6 schema, and `--config` never reads it. Dead file. |
| archlegion | `docs/01-desktop.md` | Targets Legion Y520 / GTX 1060. Suggests `optimus-manager` (unmaintained, superseded by envycontrol) and LightDM. |
| archlegion | `config/pacuser.conf` | Y520-era GPU + `linux-lts`+`linux-zen` dual-kernel default. |

---

## 4. Target repository layout

```
archloq/
├── archinstall/
│   ├── README.md                       # the profile, the validator, four archinstall bugs
│   ├── user_configuration.json         # validated against archinstall's own parser
│   ├── user_credentials.json.example   # the shape only; never the real one
│   └── validate.py                      # imports archinstall and runs ArchConfig.from_config
├── config/
│   ├── loq.conf                        # single source of truth, every flag opt-in
│   ├── legiond/legiond.ini             # fan curves, charge limits
│   ├── modprobe.d/lenovo-loq.conf      # i915, audio, USB autosuspend
│   ├── timeshift/timeshift.json        # snapshot type and exclusions
│   └── applications/chromium-flags.conf
├── install-scripts/
│   ├── pacmaster.sh                    # --resume, --audit, --from N, --list
│   ├── README.md
│   ├── lib/utils.sh                    # config validation, idempotency markers, logging
│   └── app/
│       ├── 01_kernel_boot.sh           # LUKS keyfile, crypttab, fstab, systemd-boot, resume
│       ├── 02_gpu_nvidia.sh            # nvidia-open-dkms + envycontrol + modprobe.d
│       ├── 03_power.sh                 # PPD + thermald + legiond, TLP removed
│       ├── 04_cpu_undervolt.sh         # conservative values, msr, service
│       ├── 05_desktop_xfce.sh          # Xfce + SDDM + fonts + icons
│       ├── 06_hardening.sh             # nftables, fail2ban, sudo, sysctl
│       ├── 07_snapshots.sh             # btrfs-assistant + timeshift + crontab
│       ├── 08_backup_borg.sh           # EROSBACKUP mount, repo, timers
│       ├── 09_dotfiles.sh              # deploy + verify
│       ├── 10_software.sh              # dev stack, no LLM
│       ├── 90_postinstall.sh           # audit; exits non-zero on anything that matters
│       └── 99_safe_reboot_check.sh     # gate; refuses to declare success
├── manage/
│   ├── loq-preflight.sh                # what erasing the NVMe would lose
│   ├── loq-backup.sh                   # borg create/prune/list/check/extract
│   ├── loq-restore.sh                  # restore from an archive
│   ├── loq-snapshot.sh                 # labelled pre-upgrade restore points
│   └── loq-uv-diagnose.sh              # stress + WHEA/MCE detection, bisect
├── dotfiles/
│   ├── install.sh                      # symlinks config/, copies the xfconf tree
│   ├── xinitrc
│   ├── tools/gen-xfwm4-theme.py        # generates the theme's XPM assets
│   ├── config/
│   │   ├── xfce/xfce-perchannel-xml/   # versioned xfconf state
│   │   ├── xfwm4/themes/mocha/         # themerc + generated XPM assets
│   │   ├── xsettings/                  # /Net /Xft /Gtk /Gdk only; bool/int/string only
│   │   ├── xbindkeys/                  # mouse bindings only
│   │   ├── foot/                       # terminal
│   │   ├── gtk-3.0/, gtk-4.0/
│   │   └── nvim/ zsh/ starship/ btop/ bat/ cava/ fastfetch/ kvantum/
│   ├── scripts/                        # 00, 09-11, 20-23, verify, rollback, reapply
│   └── wallpapers/
└── docs/
    ├── REFORMAT-XFCE.md                # this file: the design and its rationale
    ├── INSTALLATION.md                 # the executable runbook
    ├── PARTITIONING.md                 # byte-exact offsets; archinstall and parted routes
    ├── WIFI.md                         # getting online in the ISO
    ├── BACKUP.md                       # the external HDD as a borg target
    ├── RECOVERY.md                     # four independent recovery paths
    ├── GPU_SETUP.md                    # Blackwell, envycontrol, troubleshooting
    ├── POWER_MANAGEMENT.md             # PPD, thermald, legiond, and why TLP went
    ├── CPU_TUNING.md                   # undervolt domains and how to validate them
    ├── FAN_CONTROL.md                  # legiond scope and the degradation path
    ├── XFCE.md                         # desktop layout, panel, keybindings
    └── SECRETS.md                      # what is stored where
```

---

## 5. Install strategy

### 5.1 Phase 0 — pre-wipe backup (from the current Omarchy install)

**Nothing gets wiped before this completes and is verified.**

1. `git status` audit across every repo under `~/Projects`; push or bundle uncommitted work.
2. borg-archive of `~/.config`, `~/.ssh`, `~/.gnupg`, `~/.local/share/keyrings`,
   `~/Documents`, `~/Projects`, `/etc` (selective), pacman package list, systemd unit
   listing, `systemctl list-units`, `/boot` entry list, NVIDIA/xrandr output, keyboard map.
3. Record: LUKS header backup (`cryptsetup luksHeaderBackup`), current disk layout, ESP GUID.
4. Verify the borg repo with `borg check` and confirm a restore of one file.

### 5.2 Phase 1 — archinstall (minimal, interactive once, then scripted)

Run `archinstall` from the ISO with our settings, then **Save configuration** and commit both
generated files. We do **not** hand-write the JSON: `archinstall` is now at 4.x and the schema
changed under both existing profiles.

Settings selected in the menu:

| Screen | Value |
|--------|-------|
| Locales | `it_IT.UTF-8`, keyboard `it` |
| Mirror | Italy, Germany, France; parallel downloads 10 |
| Disk | `nvme0n1`, `wipe: true` |
| → p1 | `fat32`, 1 GiB, `flags: [boot]`, `mountpoint: /boot` |
| → p2 | `btrfs`, remainder (~952 GiB), `mountpoint: null`, subvols below |
| Disk encryption | `luks`, p2 |
| → subvols | `@`→`/`, `@home`→`/home`, `@var`→`/var`, `@snapshots`→`/.snapshots` |
| Bootloader | `systemd-boot`, `uki: false`, `removable: false` |
| Kernel | `linux-zen` |
| Network | NetworkManager, DHCP |
| Audio | pipewire |
| Profile | **None** (`profile_config.profile` omitted) — no DE, no graphics driver |
| Packages | `base`, `base-devel`, `linux-zen`, `linux-zen-headers`, `linux-firmware`, `intel-ucode`, `git`, `vim`, `nano`, `wget`, `curl`, `openssh`, `networkmanager`, `btrfs-progs`, `cryptsetup`, `efibootmgr`, `mkinitcpio` |
| Swap | **off** |
| Hostname | `loq` |
| User | `autcir`, groups `wheel,storage,power,audio,video,network,input` |

Deliberate omissions:

- **No `@log` / `@pkg` subvolumes.** archinstall's nested-subvolume `fstab` handling is
  unreliable (upstream bug reports); timeshift exclusion lists cover `/var/log` and
  `/var/cache` correctly with zero extra mount points.
- **No `/home` swapfile, no hibernation.** 31 GiB RAM. See §5.4.
- **No DE profile, no `gfx_driver`.** Both are handled by `install-scripts/app/`.

`custom_commands` carries only the two things archinstall cannot express:

```
edit mkinitcpio.conf -> HOOKS=(base udev autodetect microcode modconf kms keyboard
                        keymap consolefont systemd sd-encrypt btrfs filesystems fsck)
generate /etc/cryptsetup-keys.d/loq-root.key and luksAddKey it
```

### 5.3 Phase 2 — repo scripts

```bash
git clone https://github.com/ciroautuori/archloq /root/archloq
$EDITOR /root/archloq/config/loq.conf      # review before anything runs as root
/root/archloq/install-scripts/pacmaster.sh
```

`pacmaster.sh` runs `app/01..10`, then `99_safe_reboot_check.sh` which refuses to continue
and prints a summary if any check fails.

### 5.4 Swap / hibernate — corrected

The earlier disk question offered "zram + swapfile for hibernate". With 31 GiB of RAM that is
the wrong call, and a btrfs swapfile actively fights the snapshot scheme (a snapshotted swapfile
corrupts resume; an unsnapshotted one lives in a subvolume timeshift must exclude).

**Decision:** `zram-generator` at `zstd`, `size = 50% RAM`, `compression_algorithm = zstd`,
`swap_priority = 100`. No disk swap. Suspend only.

Opt-in path if ever wanted (`LOQ_ENABLE_HIBERNATE="0"` by default): dedicated `@swap` subvolume,
excluded from timeshift, `chattr +C`, `fallocate` file sized to `MemTotal + 2 GiB`, resume
offset computed at install time via `filefrag -v`, `resume=` added to `kernel cmdline` by
`systemd-boot` `loader.conf` — not `mkinitcpio.conf`, which only applies to GRUB.

---

## 6. Disk layout

**Revised after review.** The original draft put everything in subvolumes of one
partition. The requirement is four partitions (EFI / swap / root / home), and
that is also better: a swap *partition* sidesteps the btrfs-swapfile-vs-snapshot
conflict that would otherwise force hibernate off, and a separate `/home` means a
root rollback cannot touch your files.

Full reference, including the manual `parted` sequence:
**[PARTITIONING.md](PARTITIONING.md)**.

```
nvme0n1  1024209543168 bytes (2000409264 sectors, ≈953.87 GiB)
├── p1  start 1 MiB      size 1024 MiB      FAT32   ESP, mount /boot
├── p2  start 1025 MiB   size 40960 MiB     swap    LUKS2
├── p3  start 41985 MiB  size 204800 MiB    btrfs   LUKS2, mount / + /var + /.timeshift
└── p4  start 246785 MiB size 729976 MiB    btrfs   LUKS2, mount /home
```

Every start and length is an exact multiple of 1 MiB — archinstall rejects
anything else with `Partition is misaligned`. p4 stops 1 MiB short of the disk
end so it cannot collide with the GPT backup header.

| Subvolume | Mountpoint | Snapshotted |
|-----------|-----------|-------------|
| `@` | `/` | yes |
| `@var` | `/var` | yes |
| `@.timeshift` | `/.timeshift` | no — it is the target |
| `@home` | `/home` | **no** — borg covers it |

`@.timeshift` matches timeshift's own default path, so no reconfiguration is
needed.

`/etc/fstab` (target):

```
UUID=<esp>       /boot          vfat   umask=0077                                        0 0
/dev/mapper/root /              btrfs  subvol=@,compress=zstd,noatime,ssd,space_cache=v2 0 0
/dev/mapper/root /var           btrfs  subvol=@var,compress=zstd,noatime,ssd,space_cache=v2 0 0
/dev/mapper/root /.timeshift    btrfs  subvol=@.timeshift,compress=zstd,noatime,ssd,space_cache=v2 0 0
/dev/mapper/home /home         btrfs  subvol=@home,compress=zstd,noatime,ssd,space_cache=v2 0 0
UUID=<eros>     /mnt/erosbackup ext4  defaults,noatime,nodev,nosuid                     0 2
```

- `subvol=` by **name**, never `subvolid=`. A pinned subvolid silently breaks
  snapshot rollback, because a rolled-back root is a different subvolume.
  `01_kernel_boot.sh` strips any `subvolid=` that `genfstab -U` writes.
- The btrfs **top-level (subvolid 5)** is left unmounted, so a snapshot can be
  mounted read-only during recovery.

### Swap: zram *and* a partition

- **zram** (zstd) is installed by archinstall itself and is what the running
  system uses. No swapfile, no `vm.swappiness` games.
- **The swap partition** exists for hibernate only, is LUKS2, and is unlocked by
  the same initramfs keyfile as root. `LOQ_ENABLE_HIBERNATE="0"` by default;
  enabling it is a config line plus a reboot, because the partition is already
  there and already unlocked.

### LUKS unlock

```
# /etc/crypttab
root  UUID=<uuid>  /etc/cryptsetup-keys.d/loq-root.key  none  luks,initramfs
swap  UUID=<uuid>  /etc/cryptsetup-keys.d/loq-root.key  none  luks,initramfs,nofail
```

systemd-boot cannot prompt for a LUKS passphrase, so the initramfs is the only
place one can appear. Embedding the keyfile removes the prompt entirely.

**The passphrase stays valid in slot 0 for the life of the machine.**
`crypttab` has no OR-semantics between a keyfile and a passphrase, so the
keyfile is the boot path and the passphrase is the recovery path
([RECOVERY.md §5](RECOVERY.md)) — there is no fallback *prompt*, only a fallback
*credential*.

## 7. Boot: linux-zen + systemd-boot

- `/boot/loader.conf`: `default arch-*`, `timeout 3`, `console-mode max`,
  `editor no`, `random-seed off`.
- Kernel entries come from the `sd-boot` package + `kernel-install` hook
  (`/etc/kernel/install.conf.d/60-archloq.conf`), so `pacman -Syu` regenerates entries and
  prunes stale ones automatically. No hand-rolled `bootctl add`.
- `linux-zen` → `nvidia-open-dkms` rebuilds through the standard `dkms` hook. Expected cost:
  ~2-4 min per kernel bump, one extra boot entry.
- **Secure Boot disabled** in the BIOS before booting the ISO. Consequences: no `sbctl`, no
  key enrolment, no EFI variable signing. If Secure Boot is ever re-enabled later, that is a
  separate, non-trivial project.
- `intel-ucode` in the initramfs, before `kms`.

---

## 8. Graphics

```
nvidia-open-dkms  nvidia-utils  nvidia-settings  nvidia-prime  lib32-nvidia-utils
libva-nvidia-driver  vulkan-nouveau  libvulkan-intel
envycontrol (AUR)
```

`/etc/modprobe.d/nvidia.conf`:

```
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_DynamicPowerManagement=0x02 NVreg_PreserveVideoMemoryAllocations=1
```

Rationale:

- **GB206M has no proprietary driver.** `nvidia-open` is the only option and it is what is
  already installed today. The `nvidia-dkms` line in `01_kernel_nvidia.sh` must die.
- `NVreg_DynamicPowerManagement=0x02` = fine-grained RTD3. Turing+ only. Required for the
  "hybrid" mode to actually idle the dGPU between frames.
- GSP firmware is mandatory on `nvidia-open` (cannot be disabled) — do not carry over any
  `NVreg_EnableGpuFirmware=0` folklore from the closed-driver era.
- `envycontrol` drives `systemd-sysctl` PRIME profiles and is explicitly documented as
  compatible with **SDDM** (§10).
- Modes: `hybrid` (default), `integrated` (battery, internal panel only — external outputs are
  dGPU-wired on this chassis), `nvidia` (plugged in, external display, G-Sync).
- **`supergfxctl` is not used.** The ArchWiki currently advises against installing it during
  its transition to the successor `cardwire`, unless VFIO is required. No VFIO here.
- `optimus-manager` / `bumblebee` / `bbswitch`: not used, unmaintained or incompatible.

---

## 9. Power

```
power-profiles-daemon   # policy
thermald                # undervolt + temperature thresholds
legiond (AUR)           # fan curves, performance modes, charge thresholds
```

**TLP is removed entirely.** `config/tlp.d/`, `docs/POWER_MANAGEMENT.md`'s TLP content and
`scripts/loq-mode` / `loq-power-apply` / `loq-power-diag` all get rewritten or removed. PPD owns
`/sys/devices/system/cpu/cpu*/cpufreq/*` and the GPU runtime PM policy; TLP writing the same
knobs on top is the conflict the old script had.

- `power-profiles-daemon` also keeps `amd-pstate`/`intel_pstate` (`powersave`/`performance`)
  and is the mechanism envycontrol uses to react to the GPU mode. One owner per knob.
- `legiond` is scoped to EC-level hardware: fans, power-limit, charge thresholds, Fn+Q modes.
  Verify LOQ 17IRX10 support in its model list; if unsupported, the script degrades to
  `thermald` only and says so, rather than failing.
- No `auto-power-profiles-daemon`: it reintroduces TLP.

---

## 10. Desktop: Xfce

### Packages

```
xfce4  xfce4-panel  xfwm4  xfdesktop  thunar  xfce4-session  xfce4-settings  xfconf
xfce4-appfinder  xfce4-notifyd  xfce4-screensaver  xfce4-power-manager
xfce4-clipman  xfce4-whiskermenu-plugin  xfce4-docklike-plugin  xfce4-screenshooter
xfce4-pulseaudio-plugin  xfce4-terminal  mousepad
sddm  sddm-greeter-theme
xbindkeys  xdotool  wmctrl
lxpolkit  gnome-keyring
pipewire  pipewire-pulse  wireplumber  pavucontrol
foot  # terminal
xorg-server  xorg-xinit  xorg-apps
```

Explicitly **not** installed: `xfce4-goodies` (bulk: gigolo, gvfs-* extras, mousepad
duplicates), `xfce4-screenshooter` extras, `picom`.

### Decisions I made (flag for correction)

- **Display manager: `sddm`.** Not asked. Rationale: one small binary, Qt-based theming without
  a Qt session, documented on the ArchWiki, and listed as supported by envycontrol. `LightDM`
  (what `archlegion` used) also works; say the word if you prefer it.
- **Compositor: xfwm4's built-in one.** No picom. Configured in `xfwm4-settings` → Tweaks
  (vblank, `smoothing`, no screen-edge snapping that fights fullscreen video).
- **Focus model: click-to-focus.** xfwm4 default; `focus-new-windows` smart placement off.
- **Alt+Tab:** native xfwm4 switcher. No `alt-tab-windows`/`skip-taskbar` hacks.
- **Terminal: `foot`.** From your Omarchy-era defaults, tiny, zero config. `alacritty` or
  `ghostty` are drop-in substitutes.
- **Workspaces:** 4, 2x2 grid.
- **Panel:** two-panel profile via `xfce4-panel-profiles` — top: whisker menu + window
  buttons + workspace switcher + clock; bottom: docklike + systray + indicator + netload +
  bat + cpugraph + genmon (env/fan). Managed as versioned XML, not via GUI clicks.

### Keybindings

Declared once as `xfconf` properties in `dotfiles/config/xfce/xfce-keyboard-shortcuts.xml`
(survives package updates, unlike autostart keybinds):

```
Super            whisker menu          Super+Shift+Esc   power off dialog
Super+P          app finder            Super+S           screenshot (full screen)
Super+Return     foot                  Super+R           run dialog
Super+1..4       workspace N           Super+Shift+1..4   move window to workspace N
Super+Left/Right move workspace         Super+H           minimize
Super+Up         maximize              Super+Down         unmaximize
Super+Q          close window          Super+Shift+H      show desktop
Alt+Tab          xfwm4 native          XF86Audio*/XF86MonBrightness*  native
Super+middle     maximize vertically   Super+right-click  close window
```

Mouse bindings use `xbindkeys` (the Xfce-native path), not compositor-specific global hotkeys,
so they work identically if xfwm4's compositor is ever disabled.

### Theme

| Layer | Choice | Source |
|-------|--------|--------|
| GTK3/4 | Catppuccin Mocha | recycled `dotfiles/scripts/04-theme-catppuccin.sh` |
| xfwm4 | Catppuccin Mocha | new, matching titlebar |
| Qt / SDDM | Kvantum Catppuccin Mocha Blue | **recycled as-is** from `dotfiles/config/kvantum/` |
| Icons | Papirus + Papirus-Dark | `pacman` |
| Fonts | JetBrainsMono Nerd Font, Inter, Noto Sans | `pacman` |
| Cursor | Bibata Hybrid | `pacman` |
| Terminal | foot + Catppuccin Mocha | new profile |
| Shell | zsh + starship + Catppuccin | **recycled as-is** (`config/zsh`, `config/starship`) |
| Editor | neovim | **recycled as-is** (`config/nvim`) |
| btop / bat / fastfetch / cava | Catppuccin variants | **recycled as-is** |

Known limitation, stated up front: `libadwaita` apps (GNOME Calculator, GNOME Text Editor,
any Flatpak using the GTK4 libadwaita stack) ignore GTK3 themes. They will look light-on-dark
mismatched. Mitigated by preferring Xfce-native and GTK3 apps; not "fixed".

---

## 11. Software (dev, no LLM)

```
base      git git-lfs base-devel sudo zsh starship tmux neovim mousepad
cli       bat fastfetch btop cava tree eza ripgrep fd fzf zoxide
          rsync wget curl jq yq man-db man-pages lsd
          diff-so-fancy git-delta
langs     nodejs npm pnpm  python python-pip uv
cont      docker docker-compose  kubectl helm k9s  kubectl-ctx  github-cli
media     ffmpeg  (opt-in)
browsers  firefox (opt-in)  chromium / google-chrome (opt-in)
```

Removed: `ollama`, `llama.cpp`, `open-webui`, `cuda-dkms`, `docs/LLM_STACK.md`. `cuda` itself
stays available as `nvidia-utils` + `libcuda` via `nvidia-open-dkms` for Docker GPU passthrough,
so `docker run --gpus all` keeps working if you ever want it — without a host-side LLM stack
idling on the GPU.

AUR helper: **`yay`** kept. Not worth migrating to `paru` as part of a reinstall; it can be a
follow-up.

---

## 12. Dotfiles: recycle map

| Keep (unchanged) | Replace | Delete |
|------------------|---------|--------|
| `config/nvim/init.lua` | `config/hypr/*` → `config/xfce/*` | `install-scripts/install-hyprland.sh` |
| `config/zsh/.zshrc` | `config/waybar/*` → `config/xfce4-panel/*` | `config/kwin/kwinrc.relevant` |
| `config/starship/starship.toml` | `config/rofi/*` → (whisker menu + app finder) | `config/konsole/*` → foot profile |
| `config/btop/*`, `config/bat/*` | `config/kvantum/*` → keep, retarget Qt only | `scripts/05-plasma-widgets.sh` |
| `config/fastfetch/config.jsonc` | `config/cava/config` → keep | `scripts/06-konsave-backup.sh` |
| `config/kvantum/catppuccin-mocha-blue/*` | `config/mako/config` → `xfce4-notifyd` | `config/mako/*` |
| `wallpapers/catpuccin.jpeg` | `dotfiles/scripts/0[1-4],0[8-9],10-11` → keep | `dotfiles/scripts/12-transparency-blur.sh` (KWin) |

Everything is deployed by symlink into `~/.config` with `dotfiles/scripts/reapply.sh` and
verified by a rewritten `verify-catppuccin.sh` that checks the Xfce properties actually exist
in `xfconf-query -c xfce4-keyboard-shortcuts -l` rather than assuming file paths.

---

## 13. Security

- `nftables`: default drop inbound, accept loopback + established, accept SSH, log drops.
  IPv4 and IPv6 in one ruleset, ICMPv6 allowed (critical — dropping it breaks IPv6 entirely).
- `fail2ban` with `sshd` jail, 5 tries / 10 min ban / bantime 1 h.
- `sudo`: `%wheel` in `%sudo ALL=(ALL:ALL) ALL`. **No `NOPASSWD`.** Password required, with
  `Defaults editor` so visudo does not open a full terminal.
- `sysctl` hardening: `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`,
  `net.ipv4.conf.all.rp_filter=1`, `net.ipv4.tcp_syncookies=1`, `net.ipv4.ip_forward=0`
  unless `LOQ_ENABLE_DOCKER="1"`, `fs.suid_dumpable=0`, `kernel.unprivileged_bpf_disabled=1`,
  `vm.swappiness` left to zram-generator, no `vm.swappiness=0` (it fights zram).
- `unattended-upgrades`: not installed. Arch updates are manual.
- No firewalld, no AppArmor, no auditd (decision 13).
- `kernel.randomize_va_space=2` left at distro default.

---

## 14. Snapshots

`btrfs-assistant` daemon manages snapshots; `timeshift` drives the schedule on top.

| Subvolume | Snapshotted |
|-----------|-------------|
| `@` | yes |
| `@var` | yes (with `/var/log` + `/var/cache` excluded) |
| `@home` | **no** |
| `/.snapshots` | no (it *is* the target) |

Retention: 5 hourly, 4 daily, 3 weekly, 2 monthly.

`/boot` is **not** snapshot (it is FAT32, cannot be). Rolling back `@` therefore does not roll
back the kernel; recovery = `pacman -U` the previous `linux-zen` package from the pacman cache,
or boot any remaining systemd-boot entry. Documented in `docs/RECOVERY.md`.

`manage/loq-snapshot.sh` wraps explicit snapshots for the two moments that matter:
before a kernel upgrade, and before any `pacman -Syu` that touches `nvidia-open-dkms`.

---

## 15. Backup: EROSBACKUP

Currently `sdb1` (ext4, 1 TB) is mounted by udisks2 at `/run/media/autcir/EROSBACKUP` and
holds your existing data. New model:

- Mount by UUID at `/mnt/erosbackup`, `noatime,nodev,nosuid`, via fstab. No more udisks2
  dependency for the backup path.
- `borg` repo at `/mnt/erosbackup/borg/loq::archive`, `borg init --encryption repokey`.
- Client key (`~/.config/borg/loq::archive.key`) exported to EROSBACKUP. **Backup data on the
  HDD is encrypted by borg even though the filesystem is not** — flagging this because ext4 on
  an external disk is plaintext underneath.
- Repo passphrase: systemd credential, read from `~/.config/loq/secrets/borg.passphrase`
  (mode `0600`, inside LUKS2). Not a plaintext `BORG_PASSPHRASE=` in a unit file.
- `systemd --user` timer: daily 03:15, `borg create --list --filter=AMGlob --stats
  --compression lz4 --exclude-caches`, then `borg prune --keep-daily 7 --keep-weekly 4
  --keep-monthly 6`.
- Excludes: `node_modules`, `.venv`, `target`, `dist`, `.cache`, `go/pkg`, `~/.local/share/Trash`,
  docker/volumes, pacman cache.
- `manage/loq-restore.sh`: `borg list`, `borg mount`, single-file extract, and a
  `docs/RECOVERY.md` runbook that assumes the worst case (dead NVMe, new machine, only the
  HDD in hand).

---

## 16. Undervolt

`intel-undervolt` (repo extra) + `thermald`. `legiond` fan curves stay independent.

Default `loq.conf` values — deliberately conservative for Raptor Lake:

```
LOQ_UNDERVOLT_CORE="-60"      # was -100
LOQ_UNDERVOLT_UNCORE="-40"    # was  -80
LOQ_UNDERVOLT_CACHE="-30"     # was  -80
LOQ_UNDERVOLT_SA="-20"        # was  -50
LOQ_UNDERVOLT_IO="-20"        # was  -50
```

`LOQ_ENABLE_UNDERVOLT="1"` but `manage/loq-uv-diagnose.sh` is mandatory, not optional:

1. Snapshot before (`manage/loq-snapshot.sh`).
2. Load UV, run `stress-ng --cpu 16 --matrix 1 --verify --timeout 45m`.
3. Check `dmesg` for WHEA-Logger (`18/19`), MCE (`hardware error`), and throttling events.
4. On any hit, halve the offending offset and re-run, up to a hard floor of 0 mV.
5. `LOQ_ENABLE_UNDERVOLT="0"` reverts to stock and leaves everything else running.

The undervolt is applied by `thermald` + `intel-undervolt`'s udev rule, **not** by a
`systemd` oneshot that re-applies on every boot — those race with `thermald` and cause exactly
the "works after boot, lost after suspend" class of bug.

---

## 17. Execution order

```
 0  PRE-WIPE BACKUP        §5.1   — from Omarchy, verify with `borg check`
 ── human gate ──
 1  BIOS: disable Secure Boot, boot Arch ISO, verify wifi, update clock
 2  archinstall minimal    §5.2   — save config, commit both files back to archloq/
 ── human gate ──
 3  config/loq.conf review — every LOQ_ENABLE_* set deliberately
 4  pacmaster.sh           §5.3   — app/01 .. app/10
 5  99_safe_reboot_check   — prints summary, refuses on failure
 ── human gate ──
 6  first boot: LUKS passphrase (keyfile is embedded; this is the ONLY prompt)
 7  login, verify: nvidia-smi, envycontrol -g, pactl, xfce4-session --version
 8  undervolt diagnostics  §16
 9  EROSBACKUP first borg run, `borg check`
10  archive the generated archinstall profile back into archloq/
```

---

## 18. Rollback

| Situation | Action |
|-----------|--------|
| Install fails before first boot | Nothing is lost: no wipe had happened yet, and Phase 0 borg archive is intact. Boot Omarchy (which is untouched until p2 is destroyed). |
| Install fails after wipe, before first boot | Boot ISO, `cryptsetup luksOpen` with passphrase, mount `@` subvol by `subvolid=256`, chroot, fix. |
| Boot works, DE broken | `Ctrl+Alt+F2`, `pacman -S xfce4-session xfwm4 sddm`, or switch DM with `systemctl` from a TTY. Xfce state is all `xfconf` XML — delete `~/.config/xfce4/*` for a clean slate. |
| GPU driver broken | Boot an older systemd-boot entry, `pacman -U linux-zen <prev> nvidia-open-dkms <prev>`, `mkinitcpio -P`. DKMS keeps the previous module in `/var/cache/dkms` per kernel. |
| Kernel panic | Boot the previous systemd-boot entry (never deleted until you prune it). |
| Data loss | `docs/RECOVERY.md`: borg extract onto a fresh install or any other machine. |

---

## 19. Deliverables after approval

1. `archloq/archinstall/` — real `archinstall` 4.x profile, generated not guessed.
2. Rewritten `config/loq.conf` — every flag documented, defaults sane, nothing double-declared.
3. `install-scripts/app/01..10` + `90_postinstall.sh` + rewritten `99_safe_reboot_check.sh`.
4. `install-scripts/lib/utils.sh` — idempotent (re-runnable), `set -euo pipefail`, shellcheck-clean.
5. `dotfiles/` — Xfce-complete; every Hyprland/KDE file gone.
6. Rewritten `docs/`: INSTALLATION, GPU_SETUP, POWER_MANAGEMENT, CPU_TUNING, FAN_CONTROL,
   SECRETS; new XFCE.md, BACKUP.md, RECOVERY.md; deleted LLM_STACK.md.
7. `manage/loq-backup.sh`, `loq-restore.sh`, `loq-snapshot.sh`, `loq-uv-diagnose.sh`.
8. Updated `README.md` — Xfce, envycontrol, PPD, systemd-boot, no LLM stack.
9. Updated `CHANGELOG.md`.
10. `.github/workflows/ci.yml` extended: shellcheck, JSON schema validation of the
    archinstall profile against the pinned `archinstall` schema digest.

Nothing above touches the live system. Formatting only happens when you run it, on a machine
you have already backed up.

---

## 20. Open items — tell me if any is wrong

1. **SDDM over LightDM.** You never picked. I chose SDDM (§10).
2. **Four partitions, not one.** Your "home / root / swap / efi" request overrode the
   original single-partition btrfs plan (§6). A swap *partition* also made hibernate
   possible without the btrfs-swapfile fragility.
3. **LUKS keyfile = boot path, passphrase = recovery path.** Not a fallback *prompt* (§6).
4. **`@home` not snapshotted.** Covered by borg instead (§14).
5. **Timeshift, not Snapper.** Per your choice. Snapper + `grub-btrfs` would give
   boot-from-snapshot, which systemd-boot has no equivalent of.
6. **`yay` kept** rather than migrating to `paru` (§11).
7. **Catppuccin Mocha only** — no light variant switch (§10).

---

## 21. What was built, and what the build found

The plan above is what was intended. These are things the implementation turned
up that the plan did not anticipate, recorded because they change what you should
expect.

**Four archinstall bugs, all silent.** Verified against archinstall 4.0 source; see
[archinstall/README.md](../archinstall/README.md) for the code excerpts.

1. No `encryption_password` in `--creds` → **installs unencrypted, no error**.
2. `auth_config.users` is ignored; users must be a top-level `users` key in `--creds`.
3. A user with no password is dropped → **no unprivileged account at all**.
4. `btrfs_options` / `snapshot_config` is discarded for any `--config` install, so
   archinstall never installs or configures timeshift. Hence `app/07_snapshots.sh`
   exists, and `validate.py` asserts the dead key is absent.

**A fifth, in this repo's own code.** The upstream `schema.json` in archinstall's
GitHub repo is not valid JSON (a trailing comma), so the profile was validated by
importing archinstall and running its real parser instead. `validate.py` also has
to stub the hardware lookup, because `DiskLayoutConfiguration.parse_arg` silently
skips a device it cannot find — on a machine without the target NVMe that turns
the partition table into an empty list.

**Defects fixed in the original repo, beyond the ones listed in §3:**

- `config/modprobe.d/lenovo-loq.conf` carried `options i915 enable_guc=2`, a
  parameter removed from the kernel years ago, and `options legion-laptop force=1`,
  a module superseded by `legiond`. Both gone.
- `config/applications/chromium-flags.conf` was entirely Wayland
  (`--ozone-platform-hint=auto`, `WaylandWindowDecorations`) and forced GTK4,
  which produces unthemed dialogs on an X11 session.
- The `dotfiles/scripts/00`–`03` set was One-Dark-Pro-specific, `01-terminal.sh`
  installed a `ghostty` config that had been deleted, and `09-icons-papirus.sh`
  sourced a `lib.sh` that never existed.

**Verification, and its limits.** Every script in `install-scripts/` and
`manage/` is shellcheck-clean at default severity; `archinstall/validate.py` passes.
Nothing here has been *executed* against a real install, because that would mean
wiping the disk. The Xfce scripts in particular (`21-panel.sh`,
`23-xfconf-channels.sh`) are written against xfconf property names taken from
upstream source rather than observed from a running session, and
`verify-catppuccin.sh` exists specifically to catch them being wrong on first
login.