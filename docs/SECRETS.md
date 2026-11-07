# Secrets

What lives where, which copy is authoritative, and what is deliberately not
protected. Nothing in this repository contains a secret.

---

## 1. The three that matter

### 1.1 LUKS passphrase — slot 0, never replaced

The passphrase that became the root, swap and home encryption key at
archinstall time. It lives in keyslot 0 of each LUKS container.

`01_kernel_boot.sh` generates an initramfs keyfile and registers it with
`cryptsetup luksAddKey`, which creates an **additional** slot. It never removes
or overwrites slot 0:

```bash
cryptsetup luksAddKey "$ROOT_LUKS" "$KEYFILE"
cryptsetup luksAddKey "$SWAP_LUKS" "$KEYFILE"
```

`/etc/crypttab` is written as:

```
root UUID=<uuid> /etc/cryptsetup-keys.d/loq-root.key none luks,initramfs
swap UUID=<uuid> /etc/cryptsetup-keys.d/loq-root.key none luks,initramfs,nofail
```

The keyfile is the **boot path**. The passphrase is the **recovery path**. There
is no fallback *prompt* — `crypttab` has no OR-semantics between a keyfile and
a passphrase, so the machine boots unattended or it does not boot at all, and
your way back in is a live USB with `cryptsetup open`. [RECOVERY.md §5](RECOVERY.md)
is that procedure.

`90_postinstall.sh` asserts an active slot 0 exists on root and home, and
`99_safe_reboot_check.sh` blocks a reboot unless each has **two** active
keyslots (passphrase + keyfile). That second check is what catches the case
where the keyfile exists on disk but was never registered in the header.

Keep the passphrase in a password manager. You do not enter it daily; you need
it on the day the NVMe dies.

### 1.2 Borg client key — critical, needs a third copy off the disk

`08_backup_borg.sh` creates the repository with `borg init --encryption repokey`,
which means the data is encrypted with a **client-side** key. That key is
exported to:

```
/home/autcir/.config/borg/loq::archive.key    (mode 0600, owned by autcir)
```

and copied to the backup disk itself:

```
/mnt/erosbackup/borg/loq::archive.key         (mode 0600)
```

**Two copies, one of which is on the same disk as the repository.** That is
enough to survive a lost NVMe and not enough to survive a lost or stolen EROSBACKUP
disk. Losing both keys means losing the repository: `repokey` means there is no
server-side copy of it anywhere.

The script says so at the end of a successful run:

```bash
note "back up /home/$LOQ_USERNAME/.config/borg/$LOQ_BORG_REPO_NAME.key somewhere other"
note "than the backup disk. Without it the repository is unreadable."
```

Do it explicitly, to a third location — a password-manager file attachment, a
different machine, an offline copy:

```bash
install -Dm600 "/home/$USER/.config/borg/loq::archive.key" \
  /media/<third-location>/loq-archive.key
```

Check it is there, and check it is readable as a key:

```bash
borg key export /media/<third-location>/loq-archive-key-check --path-to-remote \
  /mnt/erosbackup/borg/loq::archive --paper
```

The backup archive list includes `/home/autcir/.config`, so the in-LUKS copy is
inside every borg archive — which means losing the key is self-healing only if
you can still read an archive, which is exactly the case you cannot. Hence the
third copy.

### 1.3 Borg repository passphrase

```
/home/autcir/.config/loq/secrets/borg.passphrase    (mode 0600, dir mode 0700)
```

Inside LUKS2. Written by `08_backup_borg.sh`, which prompts twice and refuses
to configure unattended backups if the two entries do not match. Under
`LOQ_UNATTENDED=1` with no passphrase file it skips automated backups entirely
rather than inventing one.

`manage/loq-backup.sh` reads it at run time and exports it for the duration of
the borg command:

```bash
BORG_PASSPHRASE="$(cat "$passfile")"
run borg create ...
```

It is never written into a unit file. `loq-backup.service` and
`loq-backup.timer` contain only paths.

#### What that does and does not protect against

**Does:**

- The passphrase is not in `/etc/systemd/system/`, in a world-readable file, or
  in a unit file that shows up in `systemctl cat` output, process listings, or a
  config dump.
- It is at rest encrypted by LUKS2. Read the file from the raw NVMe and it is
  ciphertext.
- Directory mode 0700, file mode 0600 — no other unprivileged user on the
  machine can read it.

**Does not:**

- It is exported into the environment of the borg process. Anything that can read
  `/proc/<pid>/environ` as that user during a backup run can read it. That is
  your own user, and a compromised desktop session is your own user, so this is
  not a meaningful boundary — it is the standard arrangement, not a strong one.
- It does not protect the **client key** (§1.2). The key is the thing that
  decrypts the repository; without the passphrase `borg` cannot unlock it, but
  the key is what must not be lost.
- Borg's own encryption does not protect the metadata you hand it. Archive names,
  file counts, original paths and sizes are not encrypted by `repokey`; only file
  contents are. If that matters, use `--encryption repokey-blake2` with
  authenticated mode enabled. It is not configured here.
- It protects nothing on the EROSBACKUP ext4 filesystem underneath the
  repository. That filesystem is plaintext. Borg encrypts the data; the
  filesystem does not. `LOQ_BACKUP_EXCLUDES` reduces what is written but does not
  change this.

---

## 2. archinstall credentials

```
archinstall/user_credentials.json.example   committed: CHANGE-ME placeholders
archinstall/user_credentials.json           NEVER committed
```

The real file is not in the repo and must not be created inside it. Copy it out:

```bash
cp archinstall/user_credentials.json.example /tmp/creds.json
$EDITOR /tmp/creds.json
```

`/tmp` is the ISO's tmpfs, so it exists only for the session. archinstall also
offers to encrypt the credentials file when you save a configuration — worth
accepting, and then pass `--creds-decryption-key`.

The example contains, all required:

| Key | Becomes |
|-----|---------|
| `!root-password` | root account password |
| `encryption_password` | the LUKS passphrase (§1.1) |
| `users[]` | the unprivileged account |
| `users[].!password` | its password — **not optional**, see below |
| `users[].groups`, `users[].sudo` | wheel membership |

Two of archinstall's behaviours make these mandatory rather than conventional,
both verified against its source in [archinstall/README.md](../archinstall/README.md):
no `encryption_password` installs **unencrypted with no error**, and a user with
no password is **dropped**, leaving no unprivileged account at all.

### The validator enforces the split

`archinstall/validate.py` refuses a committed profile that carries a credential:

```bash
for forbidden in ("!password", "enc_password", "root_enc_password",
                  "encryption_password", "!root-password"):
    if forbidden in data:
        die(f"profile contains credential key {forbidden!r}; keep it in --creds only")
```

It also asserts the inverse: the profile must **not** declare `users` (they
belong in `--creds`), the creds example must contain `encryption_password`,
`!root-password` and `users`, and every creds user must have a username and a
password. A validator that only checks the profile would pass while the real
install came out unencrypted, so it merges the creds document before parsing.

---

## 3. `.gitignore`d patterns

From `.gitignore`:

```
*.key          *.pem          *.secret        secrets/
*.gpg          *.gpg.bak      .env            .env.local      *.env
~/.ssh/id_rsa  ~/.ssh/id_ed25519  ~/.ssh/config  ~/.ssh/*.pub
~/.gnupg/private-keys*     gnupg/backup/
~/.docker/config.json
~/.claude.json             (with !~/.claude.json.example)
config/*.local  config/*secrets*  config/*password*  config/*key*
config/secrets.json
runtime/*                   (runtime/ is deleted; the rule is vestigial)
```

with un-ignores so templates survive:

```
!*.example    !*.template    !*.sample    !*_template    !*_sample
```

Two things to know about these:

- `config/*secrets*` **also matched** `config/secrets.json.example`, which
  `docs/SECRETS.md` tells you to copy. That was fixed in 1.0.0 and the
  `!*.example` rule is the fix. Do not remove the un-ignore rules.
- `config/secrets.json.example` is a template for **third-party API keys** —
  OpenAI, Anthropic, Cloudflare, Google, Meta, Discord, Telegram and others. It
  has nothing to do with the system secrets above; it exists because the user
  keeps API tokens in this repo's shape. Copy it, fill it, keep it out of git:

  ```bash
  cp config/secrets.json.example ~/.config/loq/secrets.json
  chmod 600 ~/.config/loq/secrets.json
  ```

  No install script reads it. It is yours.

CI runs a private-key scan on every push; see `.github/workflows/ci.yml`.

---

## 4. Deliberately not done, and why

### No unattended upgrades

Arch is a rolling release. `unattended-upgrades` exists to apply security patches
to a stable distribution on a schedule; on Arch, an unattended partial upgrade
is how you break a system — `pacman -Sy` without `-u` desynchronises the
database against installed packages and produces loader failures. Updates here
are manual and taken as a whole transaction.

### No passwordless sudo

`LOQ_SUDO_NOPASSWD="0"`. `06_hardening.sh` writes
`%wheel ALL=(ALL:ALL) ALL` with no `NOPASSWD`, and `90_postinstall.sh` treats an
active `NOPASSWD` rule for wheel as a **problem**.

The convenience is real and the cost is too: with no password, every command
your session runs as root is indistinguishable from an attacker's, and the one
moment you want to know something ran as root is exactly the moment nothing asks.
It also means a script that gets a stray `sudo` in it has no friction point.

Related: membership of the `docker` group **is** root-equivalent. `10_software.sh`
says so when it adds you.

### No firewalld, no AppArmor, no auditd

The machine is a laptop. `06_hardening.sh` ships a hand-written nftables
ruleset that defaults the input chain to drop, accepts loopback and established
traffic, allows ICMPv6 (dropping it breaks IPv6 entirely while IPv4 looks fine),
opens only SSH, and logs drops. That covers the realistic threat — a laptop on
Wi-Fi — with a ruleset you can read in one screen.

`firewalld` adds a second layer of indirection over nftables and a rich language
to express the same policy. `AppArmor` and `auditd` are a distribution-abstraction
tax for maintaining policy sets against a rolling distribution, and the sysctl
set already covers the practical kernel-level exposures: `kernel.kptr_restrict=2`,
`kernel.dmesg_restrict=1`, `kernel.unprivileged_bpf_disabled=1`,
`kernel.unprivileged_userns_clone=0`, `fs.suid_dumpable=0`, `rp_filter` on.

`vm.swappiness` is deliberately **not** set, because zram-generator owns swap
policy and forcing it to 0 makes zram pointless.

### No autologin

`05_desktop_xfce.sh` looks for `AutologinUser=` in the display manager config
and blanks it if present. The greeter is the only way in.

The machine is LUKS-encrypted with an initramfs keyfile, so the passphrase does
not gate boot either. Autologin would therefore remove the last human check
before an unlocked session, on a laptop that travels.

### No SSH key-only configuration

`PasswordAuthentication` is left at its default. This is a laptop, not a bastion
host. What is tightened instead is the slow-brute-force pattern:

```
LoginGraceTime 30
MaxAuthTries 3
MaxStartups 10:30:60
```

plus fail2ban on the `sshd` jail (5 tries / 10 min / 1 h ban,
`LOQ_ENABLE_FAIL2BAN=1`) and the nftables SSH rule. `LOQ_SSH_ALLOWED_CIDRS` is
empty by default, meaning anywhere; set it to your LAN if you want to.

---

## 5. Checklist before you walk away from the machine

- [ ] LUKS passphrase in a password manager
- [ ] LUKS header backup (`/tmp/loq-preflight/luks-header-root.bin`) off the machine
- [ ] Borg client key copied to a **third** location, verified readable
- [ ] Borg repository passphrase known (it is in the LUKS-encrypted home)
- [ ] `git status` clean; nothing from `.gitignore` staged
- [ ] `borg check --verify` run at least once: `sudo ./manage/loq-backup.sh check`
- [ ] `pacman -Q tlp` reports not found

## 6. Related

- [BACKUP.md](BACKUP.md) — what is archived and what is not
- [RECOVERY.md](RECOVERY.md) — the LUKS-with-only-a-passphrase procedure
- [PARTITIONING.md](PARTITIONING.md) — which partitions are encrypted
- [../archinstall/README.md](../archinstall/README.md) — the credential-key
  semantics upstream