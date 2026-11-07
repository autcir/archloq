# Installation

The executable runbook. Follow it in order. Every command is copyable as
written. The design is in [REFORMAT-XFCE.md](REFORMAT-XFCE.md); the partition
sizes are in [PARTITIONING.md](PARTITIONING.md); the archinstall profile is
validated by [archinstall/README.md](../archinstall/README.md).

Gate each section yourself. The three marked **STOP** are the points where
getting it wrong costs data.

---

## 0. On the current system, before anything else

```bash
git clone https://github.com/ciroautuori/archloq ~/Projects/archloq
cd ~/Projects/archloq
sudo ./manage/loq-preflight.sh --mount --backup
```

Reports what erasing `/dev/nvme0n1` would destroy: uncommitted work, SSH and GPG
keys, keyrings, large directories. Captures package lists, enabled units,
`lsblk`, the LUKS headers, and the display layout into `/tmp/loq-preflight`.
Reads every risk out loud.

**STOP 1** — do not wipe until that output has no unresolved RISK, and the borg
run it offers has finished.

```bash
sudo ./manage/loq-backup.sh check     # reads the whole repository
```

See [BACKUP.md](BACKUP.md). Copy `/tmp/loq-preflight/luks-header-root.bin`
somewhere off the machine.

---

## 1. Boot the ISO, get on the network

Write the latest Arch ISO to a USB stick and boot it. Connect to Wi-Fi from the
live environment — the ISO has no saved networks, so this has to be done once,
by hand.

Full procedure, including the `iwlwifi` specifics for this machine:
**[WIFI.md](WIFI.md)**.

```bash
timedatectl set-ntp true
ip -brief address
ping -c3 archlinux.org
```

---

## 2. Disable Secure Boot

In the Lenovo firmware setup (F2 during boot), set **Secure Boot → Disabled**.

These kernels are unsigned and there is no `sbctl` here. `01_kernel_boot.sh`
checks `/sys/firmware/efi/efivars/SecureBoot-*` and refuses to run if it is
still enforced, so this is checked either way — but it stops the boot rather
than half-installing.

---

## 3. archinstall

```bash
# Profile onto the ISO's tmpfs, credentials somewhere that is not the repo.
cp ~/Projects/archloq/archinstall/user_configuration.json /root/
cp ~/Projects/archloq/archinstall/user_credentials.json.example /root/creds.json
$EDITOR /root/creds.json      # !root-password, encryption_password, !password

archinstall --config /root/user_configuration.json \
            --creds  /root/creds.json
```

`encryption_password` becomes the LUKS passphrase. It is not optional: without
it archinstall installs **unencrypted and reports no error**. Same for
`!password` on the user, without which no unprivileged account is created at all.
Both are documented with the upstream code in
[archinstall/README.md](../archinstall/README.md).

Settings in the profile, if you need to regenerate it: hostname `loq`, user
`autcir` in `wheel,storage,power,audio,video,network,input,lp`, `linux-zen`,
systemd-boot, LUKS on the btrfs partitions, no desktop profile, no `gfx_driver`,
no disk swap. Exact partition offsets:
[PARTITIONING.md](PARTITIONING.md).

**STOP 2** — before rebooting out of the installer, confirm the layout:

```bash
lsblk -f
cat /etc/fstab
cat /etc/crypttab
```

p1 vfat (ESP), p2 LUKS swap, p3 LUKS btrfs (root), p4 LUKS btrfs (home).

---

## 4. First boot

Reboot. Boot from the disk, not the ISO.

The LUKS keyfile is embedded in the initramfs by `01_kernel_boot.sh` — but that
script has not run yet on a fresh archinstall, so expect either a passphrase
prompt or a keyfile registered only if the profile's `custom_commands` ran.
Either path is correct; the recovery passphrase is the same in both.

Log in as `autcir`. If there is no unprivileged account, you hit archinstall
behaviour 3 — see [archinstall/README.md](../archinstall/README.md).

---

## 5. Install scripts

```bash
cd ~/Projects/archloq        # or /root/archloq
$EDITOR config/loq.conf      # read it. this is the whole configuration.
sudo ./install-scripts/pacmaster.sh --resume
```

`--resume` runs only the steps that have no completion marker in
`/var/lib/archloq`, so a failed step is fixed and re-run rather than restarting
the sequence. Other entrypoints:

```bash
sudo ./install-scripts/pacmaster.sh --list      # step state
sudo ./install-scripts/pacmaster.sh 01 02 07    # selected steps
sudo ./install-scripts/pacmaster.sh --from 07   # from step 07 onward
sudo ./install-scripts/pacmaster.sh --audit     # re-run 90_postinstall.sh only
```

Order: `01_kernel_boot` `02_gpu_nvidia` `03_power` `04_cpu_undervolt`
`05_desktop_xfce` `06_hardening` `07_snapshots` `08_backup_borg` `09_dotfiles`
`10_software`, then `90_postinstall.sh` (the audit) and
`99_safe_reboot_check.sh` (the gate) always run, whatever you selected.

---

## 6. Verification

```bash
# The gate again, on its own
sudo ./install-scripts/app/99_safe_reboot_check.sh

# GPU
nvidia-smi -L
envycontrol -g
lsmod | grep -E 'nvidia|i915'

# Audio, display manager, desktop
pactl info
systemctl is-enabled sddm
xfce4-session --version

# Power — exactly one owner, TLP absent
powerprofilesctl get
pacman -Q tlp 2>&1 | head -1

# Boot chain
bootctl list
cryptsetup luksDump /dev/nvme0n1p3 | grep -E 'Slot|Version'

# Firewall, snapshots
nft list chain inet loq_filter | grep policy
systemctl is-active btrfs-assistant
```

---

## 7. Undervolt diagnosis

Non-optional. The offsets are applied but unverified until this passes.

```bash
sudo ./manage/loq-uv-diagnose.sh --show        # what is applied
sudo ./manage/loq-snapshot.sh pre-kernel
sudo ./manage/loq-uv-diagnose.sh                # 45 min, CPU + AVX
sudo ./manage/loq-uv-diagnose.sh --minutes 240  # the one to trust
```

Fails on any WHEA / machine-check / EDAC error during the run. On failure:
`--reset`, halve the offending domain in `loq.conf`, re-run
`04_cpu_undervolt.sh`, repeat. Stock Raptor Lake needs no undervolt;
`LOQ_ENABLE_UNDERVOLT=0` is a valid answer.
Full details, including a known-unreliable CPU signature check:
[CPU_TUNING.md](CPU_TUNING.md).

---

## 8. First borg run

```bash
# Plug in the external disk labelled EROSBACKUP
sudo ./manage/loq-backup.sh status
sudo ./manage/loq-backup.sh create
sudo ./manage/loq-backup.sh list

# Copy the borg client key OFF this disk. Without it the repo is unreadable.
sudo install -Dm600 "/home/$USER/.config/borg/loq::archive.key" \
  /media/<somewhere-else>/loq-archive.key
```

Verify the repository, then confirm you can read an archive back:

```bash
sudo ./manage/loq-backup.sh check
sudo ./manage/loq-restore.sh --list
```

[BACKUP.md](BACKUP.md) covers what the passphrase does and does not protect
against; [SECRETS.md](SECRETS.md) covers the keys; [RECOVERY.md](RECOVERY.md)
is the worst-case runbook for a dead NVMe on a different machine.

---

## 9. Desktop, on first login

The Xfce scripts that need a live session run after you log in, not from
`pacmaster.sh`:

```bash
~/.dotfiles/scripts/20-xfce.sh
~/.dotfiles/scripts/23-xfconf-channels.sh
~/.dotfiles/scripts/21-panel.sh
~/.dotfiles/scripts/22-keybindings.sh
~/.dotfiles/scripts/verify-catppuccin.sh
```

[XFCE.md](XFCE.md) explains what each one does and why the order matters.

---

## Rollback

Something wrong after the first boot, before you have committed to it: the
three gates, in order, are `Ctrl+Alt+F2` and a TTY, a `timeshift --restore`
snapshot, or the previous systemd-boot entry. After the disk is wiped, archloq
has no rollback — that is what step 0 is for. Full matrix:
[RECOVERY.md](RECOVERY.md).