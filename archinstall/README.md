# archinstall profile

Validated against **archinstall's own parser**, not a hand-written schema.

```bash
uv venv /tmp/ai-venv
uv pip install --python /tmp/ai-venv/bin/python archinstall jsonschema
/tmp/ai-venv/bin/python archinstall/validate.py
```

Why that matters: the `schema.json` in archinstall's GitHub repository is
**not valid JSON** (a trailing comma on line 28), and the two configurations in
`archlegion/` are both unreadable by the current version — one has no
`disk_config` at all, the other is a 2.6-era schema in a file that
`--config` never reads. Writing a fourth guess would have been the same mistake
three more times.

`validate.py` imports archinstall and runs `ArchConfig.from_config` over the
profile, then asserts the decisions in `docs/REFORMAT-XFCE.md` on top of that. A
profile that passes is one the installer will accept.

---

## Files

| File | Commit? | Contents |
|------|---------|----------|
| `user_configuration.json` | yes | the whole install: disk, encryption, bootloader, kernel, mirrors |
| `user_credentials.json.example` | yes | the **shape** of the credentials, with `CHANGE-ME` placeholders |
| `user_credentials.json` | **never** | the real passwords |
| `validate.py` | yes | the validator |

`validate.py` fails if the committed profile contains `!password`,
`enc_password`, `root_enc_password` or `encryption_password`.

---

## Using it

```bash
# 1. Copy the credentials example somewhere outside the repo and fill it in.
cp archinstall/user_credentials.json.example /tmp/creds.json
$EDITOR /tmp/creds.json          # set !root-password, encryption_password, !password

# 2. Boot the Arch ISO, connect to the network (docs/WIFI.md), then:
cp /root/archloq/archinstall/user_configuration.json /root/
archinstall --config /root/user_configuration.json \
            --creds  /root/creds.json

# 3. On first boot:
git clone https://github.com/ciroautuori/archloq /root/archloq
$EDITOR /root/archloq/config/loq.conf
/root/archloq/install-scripts/pacmaster.sh --resume
```

`encryption_password` becomes the LUKS passphrase. `luksAddKey` adds the
initramfs keyfile as an *additional* slot; the passphrase stays in slot 0 for the
whole life of the machine and is the recovery path.

### Encrypting the credentials file

archinstall will offer to encrypt `user_credentials.json` when you save a
configuration. Worth accepting — it keeps the LUKS passphrase out of a file on
disk in the ISO's tmpfs. Then pass `--creds-decryption-key`.

---

## Four archinstall behaviours that will bite you

All verified against archinstall 4.0 source. They are silent, which is the
problem.

### 1. No encryption password in `--creds` → installed unencrypted

`DiskEncryption.parse_arg` begins:

```python
if not password:
    return None
```

No error, no warning. The profile says `encryption_type: luks` and the installer
happily installs three plaintext filesystems. This is why `encryption_password`
is a hard requirement in `user_credentials.json.example`, and why `validate.py`
merges the creds document before parsing — a profile validated on its own would
pass while the real install came out unencrypted.

### 2. Users must be a top-level key of `--creds`

`AuthenticationConfiguration.parse_arg` reads only `u2f_config` and
`root_enc_password`. An `auth_config.users` block is ignored, and
`ArchConfig.safe_config()` — what the "Save configuration" menu writes — never
emits users into the profile at all. Users go into the **creds** document, at the
top level, under `users`.

### 3. A user with no password is dropped

`User.parse_arguments` skips any entry where neither `!password` nor
`enc_password` is present. A creds file with a well-formed user block but no
password installs a machine with **no unprivileged account**.

### 4. `btrfs_options` is discarded for `--config` installs

```python
def parse_args(cls, subvol_args):
    mods.append(cls(entry['name'], mountpoint))      # name stays a str
...
def is_default_root(self):
    return self.name == Path('@') and self.is_root()  # compares to a Path
```

`'@' == Path('@')` is `False`, so `has_default_btrfs_vols()` is always `False` for
a JSON-loaded profile and `DiskLayoutConfiguration` throws the whole
`btrfs_options` object away. `snapshot_config` inside it never reaches the
installer.

Consequence for this repo: the profile does **not** set `btrfs_options`.
`timeshift`, `btrfs-assistant` and `cronie` are in `packages` instead, and
`install-scripts/app/07_snapshots.sh` does the real configuration. `validate.py`
asserts that arrangement so nobody "helpfully" re-adds the dead key.

---

## Sizing and alignment

Sizes are in **MiB**, not GiB, because archinstall's `Size.align()` rounds to
1 MiB and raises `Partition is misaligned` otherwise. The disk's byte count is
not a whole number of MiB, so the last partition ends at 976761 MiB with the
final MiB left to the GPT backup header. Both of those checks are archinstall's,
and both run during validation.

The stub device in `validate.py` reports the real size of this NVMe
(1024209543168 bytes). If you ever target a different disk, change
`TARGET_DISK_BYTES` and re-run.

## Partition offsets are absolute

`start` is an absolute offset, not a delta, and the validator's bounds checks
(overlap, alignment, backup-GPT collision) all depend on them being right. If you
change one partition's size you must shift every later `start`. There is no
executable bit here to run; the validator is that check.

---

## Regenerating

The committed profile was produced through archinstall's guided menu and then
verified. If you change the layout:

1. Re-run archinstall's menu with the new values
2. **Save configuration**
3. Copy the emitted `user_configuration.json` over this one
4. Run `validate.py`, and fix `EXPECTED` if the intent genuinely changed
5. Commit both