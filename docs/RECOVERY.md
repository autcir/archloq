# Recovery

Four independent things can go wrong. They are ordered by how much they hurt.

| Failure | Blast radius | Where to look |
|---------|--------------|---------------|
| Boot fails after an update | the machine will not start | [§1](#1-will-not-boot) |
| Need to undo a change | one file or one package | [§2](#2-rollback-points) |
| Root filesystem broken | the whole NVMe | [§3](#3-root-filesystem-recovery) |
| Disk gone | everything | [§4](#4-the-nvme-is-gone) |

---

## 1. Will not boot

### 1.1 systemd-boot menu does not appear

```bash
# Boot the Arch ISO. The disk does not need to be mounted to inspect it.
lsblk -f /dev/nvme0n1
mount /dev/nvme0n1p1 /mnt
ls -la /mnt/loader/entries/          # empty = archinstall never wrote entries
bootctl --esp-path=/mnt list         # what systemd-boot can see
```

If `/mnt/loader/entries` is empty, the kernel-install plugin never ran. Chroot
and run it:

```bash
cryptsetup open /dev/nvme0n1p3 root
mount -o subvol=@ /dev/mapper/root /mnt/root
mount /dev/nvme0n1p1 /mnt/root/boot
arch-chroot /mnt/root
  bootctl --esp-path=/boot install
  kernel-install add "$(uname -r)" /boot/vmlinuz-linux-zen /boot/initramfs-linux-zen.img
exit
umount /mnt/root/boot /mnt/root
reboot
```

### 1.2 Stops at "Enter passphrase for disk"

Expected if the initramfs keyfile is not being used. Check the chain:

```bash
cryptsetup open /dev/nvme0n1p3 root
mount -o subvol=@ /dev/mapper/root /mnt/root
mount /dev/nvme0n1p1 /mnt/root/boot

# 1. Does crypttab mark the devices for the initramfs?
grep -E 'root|swap' /mnt/root/etc/crypttab
#    expect: root UUID=... /etc/cryptsetup-keys.d/loq-root.key none luks,initramfs

# 2. Does the keyfile exist and have the right mode?
ls -l /mnt/root/etc/cryptsetup-keys.d/loq-root.key   # expect -r-------- root root

# 3. Does the initramfs actually contain it?
lsinitcpio -l /mnt/root/boot/initramfs-linux-zen.img | grep -i cryptsetup-keys

# 4. Does mkinitcpio have the hook?
grep HOOKS /mnt/root/etc/mkinitcpio.conf | grep -o sd-encrypt
```

Any of 1–4 failing means fix it in the chroot and `mkinitcpio -P`:

```bash
arch-chroot /mnt/root
  sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont systemd sd-encrypt btrfs filesystems fsck)/' /etc/mkinitcpio.conf
  mkinitcpio -P
exit
```

### 1.3 Booted, then the display is black

`nvidia-open` on Blackwell is strict. From a TTY (`Ctrl+Alt+F2`):

```bash
# Which entry did you boot? If it is not the newest, choose the previous one
# from the systemd-boot menu -- that alone often fixes it.
systemctl status display-manager
lspci -k | grep -A3 'VGA'
dkms status
```

Then rebuild against the older kernel and rebuild the initramfs:

```bash
ls /var/cache/pacman/pkg/linux-zen-*.pkg.tar.zst     # the cache keeps the previous one
sudo pacman -U /var/cache/pacman/pkg/linux-zen-<previous>.pkg.tar.zst
sudo mkinitcpio -P
reboot
```

Force the Intel GPU for a login if you need the machine usable right now:

```bash
# Edit /boot/loader/loader.conf, add to the cmdline line:
#   nomodeset
# or boot a TTY and start xfce with software GL:
LIBGL_ALWAYS_SOFTWARE=1 startxfce4
```

### 1.4 Suspend does not come back

Almost always `NVreg_DynamicPowerManagement` plus the driver parameters:

```bash
sudo mkinitcpio -P     # the modprobe.d change needs a rebuild, always
# as a last resort, in /boot/loader/loader.conf's cmdline:
#   nvidia_drm.modeset=0   disables the dGPU entirely, iGPU only
```

---

## 2. Rollback points

Two independent mechanisms. They have different granularity and different
coverage.

### 2.1 timeshift / btrfs-assistant (on the NVMe, fast, minutes)

```bash
sudo ./manage/loq-snapshot.sh list        # manual ones
sudo ./manage/loq-snapshot.sh list-auto   # the scheduled ones
```

**Rollback procedure.** Never roll back from the running system — btrfs refuses
to delete a subvolume it is mounted from.

```bash
# 1. Boot a live ISO.
cryptsetup open /dev/nvme0n1p3 root

# 2. Find the snapshot's subvolume id.
mount -o subvol=@.timeshift /dev/mapper/root /mnt/snapshots
btrfs subvolume list /mnt/snapshots | grep pre-kernel
#   ID 264 gen 42 top level 5 path <FS_TREE>/archive-2026-10-08T12-00-00

# 3. Mount the root snapshot read-only, and a fresh @ as the destination.
mount -o subvol=<ID>,ro /dev/mapper/root /mnt/root
mount -o subvol=@ /dev/mapper/root /mnt/target

# 4. Copy.
rsync -aAXH --numeric-ids --delete /mnt/root/ /mnt/target/

umount /mnt/target /mnt/root /mnt/snapshots
reboot
```

**`/boot` was not snapshotted.** It is FAT32; btrfs cannot snapshot it. So after
a rollback the root filesystem is older than the kernel. If the machine will not
boot:

```bash
# From a live ISO, chroot and reinstall the kernel that matches the rolled-back
# root. The package cache is on the rolled-back @var, so it is likely there.
ls /mnt/target/var/cache/pacman/pkg/linux-zen-*.pkg.tar.zst
arch-chroot /mnt/target
  pacman -U /var/cache/pacman/pkg/linux-zen-<matching>.pkg.tar.zst
  mkinitcpio -P
  bootctl --esp-path=/boot install
exit
```

### 2.2 borg (on the external HDD, coarse, days)

Faster to restore from and covers `/home`, which timeshift does not. See
[BACKUP.md §7](BACKUP.md#7-restoring).

```bash
sudo ./manage/loq-restore.sh list
sudo ./manage/loq-restore.sh extract <archive> home/autcir/Projects ./recovered
```

---

## 3. Root filesystem recovery

### 3.1 btrfs scrub

Run this before anything else. It reports errors that are fixable without a
restore:

```bash
sudo btrfs scrub start -Bd /           # blocking, with stats
sudo btrfs scrub status /
```

Errors in metadata: `btrfs restore -l /dev/mapper/root` lists the superblock
backups.

### 3.2 Read-only rescue

```bash
mount -o subvol=@,ro,rescue=/dev/sdb1 /dev/mapper/root /mnt
# /mnt/rescue now holds a full copy. Copy what matters off it, then:
umount /mnt
```

### 3.3 `/home` is a separate filesystem

```bash
cryptsetup open /dev/nvme0n1p4 home
btrfs scrub start -Bd /home
```

Because `/home` is its own LUKS container, `/home` can be mounted and repaired
with `/` unmounted. Recovering user files does not require a working root.

---

## 4. The NVMe is gone

Total hardware failure, theft, or a controller that stopped enumerating. Only
the external HDD survives.

```bash
# On any Linux machine with borg installed.
# You need: the archive, the repository passphrase, and the client key.
cp loq-borg.key /tmp/
export BORG_PASSPHRASE_FILE=/path/to/borg.passphrase
mkdir -p /tmp/restore && cd /tmp/restore

borg init --encryption repokey-blake2 --key-file /tmp/loq-borg.key repo
borg key import --paper /tmp/loq-borg.key 2>/dev/null || true
borg -r repo list
borg -r repo extract "archive-2026-10-09T03:15:22" "home/autcir/Projects"
```

If `borg key import` is required, the key you have is the **paper** key and the
repository was initialised with a different one — normally because the repository
was created with `--key-mode repokey` and you have the key file rather than the
paper key. Recovering a repository from a repokey key **file** is possible with
`borg key import` only if the file is in the same format; otherwise the archive
is not readable. This is the single most important reason to keep the key.

After recovering, reinstall Arch with the same profile and run `pacmaster.sh`.

---

## 5. LUKS passphrase — the way back into a lost keyfile

The keyfile is embedded in the initramfs for unattended boot. If it is ever lost
or the initramfs is rebuilt without it, the **passphrase in slot 0** still works.
It has not been replaced at any point in this setup.

```bash
cryptsetup luksDump /dev/nvme0n1p3 | grep -A4 'Slot: 0'
cryptsetup luksAddKey /dev/nvme0n1p3 /etc/cryptsetup-keys.d/loq-root.key
```

If the passphrase itself is lost, there is no recovery. LUKS2 is designed that
way. The only mitigation is a `luksHeaderBackup`, which `loq-preflight.sh` writes
to `/tmp/loq-preflight/luks-header-root.bin` — copy it to the backup disk. Note
that a header backup alone does **not** recover a forgotten passphrase; it helps
with corrupted headers. Back up the passphrase too.

---

## 6. First aid

```bash
# What is failing, in order of usefulness.
systemctl --failed
journalctl -p err -b --no-pager | tail -50
journalctl -b -k | grep -iE 'error|fail|warn' | tail -50

# Did the NVIDIA module build?
dkms status
modinfo -k "$(uname -r)" nvidia

# Is the undervolt suspected? Turn it off first, it is the most likely source
# of "random" instability:
sudo ./manage/loq-uv-diagnose.sh --reset

# Re-apply the intended state after fixing anything by hand:
sudo ./install-scripts/pacmaster.sh --resume
```

`pacmaster.sh --audit` re-runs every check in `app/90_postinstall.sh` and exits
non-zero if anything important is wrong. It is safe to run at any time.