# Backup — the external HDD

The 1 TB ST1000LM035-1RK172 (`/dev/sdb1`, ext4, label `EROSBACKUP`) becomes the
backup target. The repository is created **by borg**, not by the filesystem, so
the data on it is encrypted even though ext4 on an external disk is not.

---

## 1. What it is today

```
sdb     931.5G  ST1000LM035-1RK172
└── sdb1 ext4  -> /run/media/autcir/EROSBACKUP     (mounted on demand by udisks2)
```

It is not in `/etc/fstab`. It appears only when you click it in a file manager,
and `manage/loq-backup.sh` cannot rely on that.

## 2. What it becomes

```
sdb1  ext4, label EROSBACKUP
mounted at /mnt/erosbackup from /etc/fstab, noatime,nodev,nosuid
/usr/bin/sdb1                    (wrong; it is /dev/sdb1)
/mnt/erosbackup/borg/loq::archive/    borg repo, repokey encryption
/mnt/erosbackup/borg/loq::archive.key the borg client key, 0600
```

`install-scripts/app/08_backup_borg.sh` does all of it.

### Why mount by UUID and not let udisks2 do it

A backup that depends on a desktop session being open is not a backup. The
fstab entry means:

- `loq-backup.timer` works at 03:15 with nobody logged in
- a headless `ssh loq 'loq-backup.sh create'` works
- there is exactly one canonical path, so nothing fights over the mount

udisks2 is left alone: clicking the disk in a file manager still works, it just
resolves to the same filesystem. If both are active you get the disk visible in
two places, which is harmless but confusing; the scripts only ever use
`/mnt/erosbackup`.

### Encryption, honestly

The disk is **not** encrypted. Borg encrypts the archive, so a lost or borrowed
disk yields nothing readable, but anything else you write to it — including the
client key file — is plaintext. Keep it to backup data.

---

## 3. Setup

### 3.1 Run the installer step

```bash
sudo ./install-scripts/pacmaster.sh 08
```

It finds the disk by label, adds the fstab entry, mounts it, installs `borg`,
initialises the repository, and asks you for the repository passphrase.

**That passphrase is asked once and never written into a unit file.** It goes to:

```
/home/autcir/.config/loq/secrets/borg.passphrase    (0600, inside LUKS2)
```

`manage/loq-backup.sh` reads it at run time and exports it as `BORG_PASSPHRASE`
to the `borg` process for the duration of that command. It is a plain
environment variable in the process environment, not a systemd
`LoadCredential=` — visible to anything running as the same user while the
backup runs. On a single-user machine inside LUKS2 that is an acceptable trade
for not baking the key into `/etc/systemd/system/`. If you want it tighter,
that is the line to change.

Because `$HOME` is on an encrypted btrfs volume, the file is only readable after
you have booted and unlocked. Which is also why the backup cannot run before
first boot — an ordering problem with no clean solution short of storing the
passphrase on the unencrypted backup disk, which defeats the purpose.

### 3.2 Verify

```bash
./manage/loq-backup.sh status
./manage/loq-backup.sh create     # first real archive
./manage/loq-backup.sh list
```

`check` reads the entire repository and is slow. Run it once after the first
backup, then quarterly:

```bash
./manage/loq-backup.sh check
```

---

## 4. What gets backed up

Deliberately a list, not a sweep of `/home`. The reason is empirical: a
`node_modules` directory is a few hundred megabytes of files that compress to
almost nothing, and borg still has to walk all of them.

```
/home/autcir/Projects          <- the repos
/home/autcir/Documents
/home/autcir/Downloads
/home/autcir/Desktop
/home/autcir/Dotfiles          <- if you use one
/home/autcir/.config
/home/autcir/.local/bin
/home/autcir/.local/share/nvim
/home/autcir/.ssh
/home/autcir/.gnupg
/home/autcir/.zshrc
/etc/systemd/system
/etc/ssh/sshd_config.d
/etc/nftables.conf
/etc/modprobe.d
/etc/sysctl.d
/etc/crypttab
/etc/fstab
/etc/legiond.conf
/etc/intel-undervolt.conf
/etc/timeshift
```

Excluded: `node_modules`, `.venv`, `target`, `dist`, `.cache`, `go/pkg`,
`*.sock`, `*.pyc`, `flatpak`, `.local/share/Trash`, browser caches.

**`/home` as a whole is not snapshotted.** These archives plus the timeshift
snapshots on the NVMe are the two independent recovery paths, and they do not
overlap much.

---

## 5. Schedule

`/etc/systemd/system/loq-backup.timer`, daily at 03:15, `Persistent=true` so a
laptop that was asleep at 03:15 catches up on the next boot rather than skipping
the day. `RandomizedDelaySec=30m` keeps it off a fixed minute on the hour.

```bash
systemctl list-timers loq-backup.timer
systemctl status loq-backup.timer
sudo systemctl start loq-backup.timer     # force a run
journalctl -u loq-backup -f              # watch it
```

Retention, applied on every prune:

```
--keep-daily 7  --keep-weekly 4  --keep-monthly 6  --keep-within 7d
```

Edit in `config/loq.conf` and re-run `app/08`, or call
`./manage/loq-backup.sh prune` directly with your own flags.

---

## 6. The client key — the thing most people lose

`repokey` means the repository is encrypted with a key that lives **only** on
the client.

```bash
# Regenerate and store it somewhere that is not the backup disk:
borg -r /mnt/erosbackup/borg/loq::archive key export ~/loq-borg.key

# For example, a password manager's encrypted note, or an encrypted USB stick.
```

`app/08` exports it to `~/.config/borg/loq::archive.key` (backed up by borg
itself) and copies it to the backup disk. Both copies are useless if the disk
dies. Keep a third copy elsewhere.

Without it, the archive is a directory of unreadable bytes. There is no
administrator reset for borg `repokey` repositories.

---

## 7. Restoring

```bash
./manage/loq-restore.sh list                    # archives, oldest first
./manage/loq-restore.sh contents archive-2026-10-09T03:15:22
./manage/loq-restore.sh extract archive-2026-10-09T03:15:22 home/autcir/Projects/archloq ./recovered
./manage/loq-restore.sh mount   archive-2026-10-09T03:15:22    # browse as a filesystem
```

Whole home, overwriting what is there now:

```bash
./manage/loq-restore.sh restore-home archive-2026-10-09T03:15:22
```

### On a machine that is not this one

You need three things, and this is why they are all backed up:

1. the archive: the backup disk
2. the passphrase: your password manager or `~/.config/loq/secrets/borg.passphrase`
3. the client key: `loq::archive.key`

```bash
# on any Linux box with borg installed
cp /path/to/loq-borg.key /tmp/
mkdir -p /tmp/restore && cd /tmp/restore

export BORG_PASSPHRASE_FILE=/path/to/borg.passphrase
borg init --encryption repokey-blake2 --key-file /tmp/loq-borg.key repo
borg key import --paper /tmp/loq-borg.key    # if the key does not already match
borg -r repo list
borg -r repo extract "archive-2026-10-09T03:15:22" "home/autcir/Projects"
```

If the key is gone but you still have `~/.config/borg/loq::archive.key` from the
old home directory, use that instead. If both are gone, the archive is
unrecoverable. Full runbook: [RECOVERY.md](RECOVERY.md).

---

## 8. Before you wipe the NVMe

The one time this matters most, and it is the time people forget:

```bash
sudo ./manage/loq-preflight.sh --mount --backup
```

That runs the full data-loss audit, mounts the backup disk, and takes an
archive. See [PARTITIONING.md §1](PARTITIONING.md) for what the NVMe layout
becomes. The order is:

1. `loq-preflight.sh --mount --backup` on the **current** system
2. boot the Arch ISO
3. `archinstall --config archinstall/user_configuration.json --creds /tmp/creds.json`
4. first boot, then `pacmaster.sh --resume`
5. `./manage/loq-backup.sh status` — confirm it still works

Step 5 matters: the new system's `borg` is a different version than the one that
wrote the archive, and a repository created by a newer borg is unreadable by an
older one. This one will match, but verify rather than assume.