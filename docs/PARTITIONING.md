# Partitioning — the NVMe, before and after

Target: `/dev/nvme0n1`, WD PC SN7100S SDFPMSL-1T00-1101, **1024209543168 bytes**
(2000409264 sectors of 512 B, ≈953.87 GiB).

Everything here is also in `archinstall/user_configuration.json`, and
`archinstall/validate.py` checks the two against each other and against
archinstall's own parser. If you change one, change the other and re-run:

```bash
uv venv /tmp/ai-venv
uv pip install --python /tmp/ai-venv/bin/python archinstall jsonschema
/tmp/ai-venv/bin/python archinstall/validate.py
```

---

## 1. What is on the disk right now

```
nvme0n1  1024209543168 bytes, GPT
├── p1  start 2048      size 4194304 sectors (2 GiB)   vfat     -> /boot
└── p2  start 4196352   size 1996210176 sectors         crypto_LUKS -> btrfs (subvol @)
```

Single LUKS container, one btrfs subvolume, no swap partition, ESP mounted at
`/boot`. There is **no unallocated space** — p2 runs to the end of the disk.

Consequence: there is nothing to shrink. "Resizing" here means deleting both
partitions and laying down four new ones. If you actually wanted to *keep* data
on the NVMe and shrink it, stop: read [§6](#6-shrinking-in-place--the-other-question).

---

## 2. Target layout

Four partitions. All starts and lengths are exact multiples of 1 MiB, because
archinstall rejects anything that is not (`Partition is misaligned`), and the
last partition stops 1 MiB short of the end so it cannot collide with the
backup GPT header.

| # | Start (MiB) | Size | Type | Mount | Encrypted |
|---|-------------|------|------|-------|-----------|
| p1 | 1 | 1024 MiB (1 GiB) | FAT32 | `/boot` | no |
| p2 | 1025 | 40960 MiB (40 GiB) | linux-swap | — | **yes** |
| p3 | 41985 | 204800 MiB (200 GiB) | btrfs | `/` + `/var` + `/.timeshift` | **yes** |
| p4 | 246785 | 729976 MiB | btrfs | `/home` | **yes** |

Last partition ends at 976761 MiB; +1 MiB of GPT reserve = 976762 MiB, which is
the whole disk. Nothing is left over.

### Why four partitions and not one

- **`/home` separate** so a root snapshot can be rolled back without touching
  your files, and so `/home` can have different mount options.
- **`/home` is not snapshotted.** Borg covers it. Snapshotting a directory tree
  containing `node_modules` and container layers would blow the retention budget
  for no benefit.
- **Swap as a partition, not a swapfile.** A btrfs swapfile is hostile to
  snapshots: snapshotting a live swapfile corrupts resume, and excluding it from
  snapshots requires a dedicated subvolume anyway. A partition sidesteps the
  whole problem and gives a real, decryptable swap.
- **ESP is 1 GiB, not 2 GiB.** 1 GiB holds several `linux-zen` images with room
  to spare.

### Subvolumes

p3 gets three:

| Subvolume | Mountpoint | Snapshotted |
|-----------|-----------|-------------|
| `@` | `/` | yes |
| `@var` | `/var` | yes |
| `@.timeshift` | `/.timeshift` | no — it is the target |

`@.timeshift` is named for **timeshift's own default snapshot path**. Using
`/.snapshots` here would work too but would need timeshift reconfigured; this way
it works with the defaults.

p4 gets one, `@home` → `/home`.

> There are deliberately **no** `@log` / `@pkg` subvolumes under `@var`.
> archinstall's nested-subvolume `fstab` generation is unreliable, and timeshift's
> exclusion list covers `/var/log` and `/var/cache` correctly with zero extra
> mount points.

### Encryption

`disk_encryption.encryption_type = "luks"` covers p2, p3, p4. The ESP stays
plain, as it must.

Two archinstall traps that this profile is written to avoid:

1. **`encryption_password` must be present in the `--creds` file.**
   `DiskEncryption.parse_arg` returns `None` when the password is falsy. A
   profile without it installs **unencrypted, silently, with no error**.
2. **The users list must be in the creds file, top-level `users`.**
   `AuthenticationConfiguration.parse_arg` ignores an `auth_config.users` key
   entirely, and `User.parse_arguments` drops any entry without a password. Get
   either wrong and you boot into a machine with **no unprivileged account**.

`archinstall/validate.py` asserts both.

### mount options

All three btrfs mounts use:

```
compress=zstd,noatime,ssd,space_cache=v2
```

`noatime` is an addition over the current `relatime`, which keeps writing inode
access times on every file read.

---

## 3. Doing it with archinstall

The profile is generated, not hand-written: boot the ISO, run `archinstall`,
choose the values below, then **Save configuration** and copy the emitted files
back into `archinstall/`. The committed profile was produced that way and then
verified with `validate.py`.

```
Locales        Italian / it_IT.UTF-8, keyboard it
Mirrors        Italy, Germany, France, parallel downloads 10
Disk config    Manual partitioning
                 /dev/nvme0n1, wipe: true
                 FAT32      1 GiB      /boot, flags boot+esp
                 linux-swap 40 GiB     flags swap
                 btrfs      200 GiB    mountpoint null
                                 subvol @       -> /
                                 subvol @var    -> /var
                                 subvol @.timeshift -> /.timeshift
                 btrfs      rest      /home, flags linux-home, subvol @home
Disk encryption  luks on the swap, root and home partitions
Bootloader      systemd-boot, uki off, removable off
Kernel          linux-zen
Swap            zram, zstd        <- NOT a disk swap
Profile         none              <- the DE comes from install-scripts/
```

Then:

```bash
cp /root/user_configuration.json  archloq/archinstall/
cp /root/user_credentials.json    /tmp/creds.json     # never commit this
archinstall --config archloq/archinstall/user_configuration.json \
            --creds  /tmp/creds.json
```

**Disable Secure Boot in the firmware before booting the ISO.** These kernels are
unsigned and `install-scripts/app/01_kernel_boot.sh` refuses to continue if it
is on.

---

## 4. Doing it by hand, in the ISO

`archinstall` will do the right thing, but if you want to see every step:

```bash
# 1. Wi-Fi (if the ISO does not auto-connect). See docs/WIFI.md.
wifi-menu

# 2. Check what you are about to destroy.
lsblk -b -d -o NAME,SIZE,MODEL /dev/nvme0n1
#    expect 1024209543168 for this drive

# 3. Partition. cgdisk is not preinstalled on every ISO image; parted is.
parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 unit MiB mkpart ESP   fat32      1     1025
parted /dev/nvme0n1 unit MiB mkpart swap  linux-swap 1025  41985
parted /dev/nvme0n1 unit MiB mkpart root  btrfs      41985 246785
parted /dev/nvme0n1 unit MiB mkpart home  btrfs      246785 976761

# 4. Set the ESP partition GUID so systemd-boot finds itself.
#    ESP GUID = C12A7328-F81F-11D2-BA4B-00A0C93EC93B
sgdisk -A 1:0:0 /dev/nvme0n1   # already correct when created with `mkpart ESP`

# 5. Encrypt swap, root and home.
cryptsetup luksFormat --type luks2 --iter-time 1000 /dev/nvme0n1p2
cryptsetup luksFormat --type luks2 --iter-time 1000 /dev/nvme0n1p3
cryptsetup luksFormat --type luks2 --iter-time 1000 /dev/nvme0n1p4
#    Pick your passphrase. It stays valid in slot 0 for the rest of the
#    machine's life and is the only way back if the keyfile is lost.

# 6. Open them and format.
cryptsetup open /dev/nvme0n1p2 swap
cryptsetup open /dev/nvme0n1p3 root
cryptsetup open /dev/nvme0n1p4 home
mkfs.fat -F32 -n EFI   /dev/nvme0n1p1
mkswap /dev/mapper/swap
mkfs.btrfs -f -L loq /dev/mapper/root
mkfs.btrfs -f -L loqhome /dev/mapper/home

# 7. Mount and create subvolumes.
mount /dev/mapper/root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@.timeshift
umount /mnt

mkdir -p /mnt/{boot,home,var,.timeshift}
mount /dev/nvme0n1p1  /mnt/boot
mount -o subvol=@,compress=zstd,noatime,ssd,space_cache=v2 /dev/mapper/root /mnt
mount -o subvol=@var,compress=zstd,noatime,ssd,space_cache=v2 /dev/mapper/root /mnt/var
mount -o subvol=@.timeshift,compress=zstd,noatime,ssd,space_cache=v2 /dev/mapper/root /mnt/.timeshift
mount -o subvol=@home,compress=zstd,noatime,ssd,space_cache=v2 /dev/mapper/home /mnt/home

# 8. Base system.
pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode \
                btrfs-progs cryptsetup efibootmgr git

genfstab -U /mnt >> /mnt/etc/fstab
```

Then chroot and finish: locale, hostname, users, `mkinitcpio` hooks,
`bootctl install`, `bootctl list`. `install-scripts/pacmaster.sh` picks up from
step 01.

**Note on step 7:** if you hand-build the fstab, write `subvol=@` by **name**.
`genfstab -U` writes `subvolid=256,subvol=/@`, and a pinned subvolid means a
rolled-back root has the wrong id — snapshot rollback silently breaks.
`01_kernel_boot.sh` strips it.

---

## 5. What `01_kernel_boot.sh` fixes up afterwards

archinstall gets the partition table right and the boot chain wrong for this
layout. That script handles:

| Thing | Why |
|-------|-----|
| LUKS keyfile in initramfs | systemd-boot cannot prompt for a passphrase; the initramfs is the only place one can appear. |
| `/etc/crypttab` `initramfs` flag | without it the keyfile is not used at boot. |
| strip `subvolid=` from fstab | see step 7 above. |
| add `noatime`, `ssd`, `space_cache=v2` | `genfstab` will not. |
| `/boot/loader/loader.conf` | boot timeout, no menu editor. |
| `/etc/kernel/cmdline` | quiet, loglevel; `resume=` if hibernation is enabled. |
| `bootctl install` | only runs if `/boot` is a mounted vfat. |
| Secure Boot check | dies if it is on. |

---

## 6. Shrinking in place (the other question)

If you want to keep data on the NVMe and give space to something else, the order
matters and there is no going back after step 3.

```bash
# 1. Mount top-level (subvolid 5) so you can see the subvolumes.
mount /dev/mapper/root /mnt
btrfs subvolume list /mnt          # note every ID

# 2. Shrink. You cannot shrink a mounted filesystem.
umount /mnt
btrfs filesystem resize -200G /dev/mapper/root

# 3. Now rewrite the partition table to match.
parted /dev/nvme0n1 unit MiB print   # confirm the new end
# then in cgdisk: delete p2, recreate it at the new size, type 8300,
# and re-create a new partition in the freed tail

# 4. Re-open and format only the new region. The LUKS container now spans
#    more than the btrfs filesystem does; that is expected and fine.
cryptsetup open /dev/nvme0n1p2 root
# find the partition holding the real end, then:
mkfs.btrfs -f /dev/nvme0n1p3       # ONLY if this is a brand new partition
```

Do **not** run `mkfs` on the partition that holds your existing data. If you are
unsure which partition is which, `btrfs filesystem show` before you touch
anything.

> Honestly: on a single-NVMe laptop with 1 TB, shrinking buys nothing. Take a
> borg backup, wipe, reinstall. That path has fewer ways to end up with an
> unbootable disk.

---

## 7. Verifying the result

```bash
lsblk -f /dev/nvme0n1                      # 4 partitions, 3 crypto_LUKS
findmnt / /home /var /.timeshift            # all btrfs
findmnt /boot                              # vfat, mounted from /dev/nvme0n1p1
sudo cryptsetup luksDump /dev/nvme0n1p3 | grep -c 'Slot:'    # 2: passphrase + keyfile
sudo /home/autcir/Projects/archloq/install-scripts/pacmaster.sh --audit
```

The audit (`app/90_postinstall.sh`) checks all of the above plus the kernel
hooks, the crypttab flags, GPU module parameters, power-service exclusivity and
the snapshot backend. It exits non-zero on anything that matters.