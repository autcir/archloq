#!/usr/bin/env python3
"""Validate archloq's archinstall profile against the real archinstall parser.

This is not a hand-written approximation of archinstall's schema. It imports
archinstall itself and runs `ArchConfig.from_config` over the profile, so a
profile that passes here is accepted by the installer that will consume it.

Usage:
    validate.py [--archinstall-root DIR] [PROFILE]

PROFILE defaults to <repo>/user_configuration.json next to this script.

Exit codes:
    0  profile parsed cleanly
    1  profile rejected (parse error / structural assertion failed)
    2  archinstall not importable (dependency missing)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent

# Not a real credential. archinstall only needs a non-empty string to parse the
# disk_encryption block; nothing in this script ever writes it anywhere.
SENTINEL_PASSWORD = "validation-only-not-a-real-credential"

# Exact size of the target NVMe (WD PC SN7100S SDFPMSL-1T00-1101), read from
# `lsblk -b`. archinstall checks the partition table against this number, so the
# stub device has to be truthful or the validator would rubber-stamp a layout
# that cannot be created.
TARGET_DISK_BYTES = 1024209543168

# Structural invariants this repo depends on. archinstall's parser is
# permissive, so these assertions encode the decisions in
# docs/REFORMAT-XFCE.md that the parser will happily ignore if wrong.
EXPECTED = {
    "hostname": "loq",
    "kernels": ["linux-zen"],
    "swap_enabled": True,
    "swap_algorithm": "zstd",
    "snapshot_packages": ["btrfs-assistant", "cronie", "timeshift"],
    "bootloader": "Systemd-boot",
    "uki": False,
    "removable": False,
    "encrypted_partition_count": 3,
    "partition_fs_types": ["fat32", "linux-swap", "btrfs", "btrfs"],
    "partition_mountpoints": ["/boot", None, None, "/home"],
    "partition_flags": [["boot", "esp"], ["swap"], [], ["linux-home"]],
    "root_subvolumes": ["@", "@var", "@.timeshift"],
    "home_subvolumes": ["@home"],
    "btrfs_mount_options": ["compress=zstd", "noatime", "ssd", "space_cache=v2"],
    "user_groups": ["wheel", "storage", "power", "audio", "video", "network", "input"],
}


def die(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def ok(msg: str) -> None:
    print(f"  ok  {msg}")


def load_archinstall():
    # archinstall configures its logger at import time and writes install.log /
    # cmd_history.txt into the current working directory. Run the whole
    # validation from a throwaway directory so importing it never litters the
    # repository.
    os.chdir(tempfile.mkdtemp(prefix="archinstall-validate-"))
    try:
        from archinstall.lib.args import ArchConfig  # type: ignore
        from archinstall.lib.models.device import ModificationStatus  # type: ignore
    except ImportError as exc:  # pragma: no cover
        print(f"FAIL: cannot import archinstall: {exc}", file=sys.stderr)
        print(
            "      install it into a venv, e.g.\n"
            "        uv venv /tmp/ai-venv && uv pip install --python /tmp/ai-venv/bin/python archinstall\n"
            "        /tmp/ai-venv/bin/python archinstall/validate.py",
            file=sys.stderr,
        )
        raise SystemExit(2) from exc

    # `DiskLayoutConfiguration.parse_arg` calls device_handler.get_device() and
    # silently *skips* a device it cannot find. On any machine that does not
    # have the target NVMe attached, that turns the whole partition table into
    # an empty list -- which then fails the encryption check with a confusing
    # "require partitions to be defined".
    #
    # The stub supplies a real Size so archinstall's own bounds checks still
    # run: 1 MiB alignment on every created partition, no overlaps, and
    # "last partition must not overlap the backup GPT header". Those are exactly
    # the checks that would otherwise only fire mid-install with a wiped disk.
    from archinstall.lib.disk.device_handler import device_handler  # type: ignore
    from archinstall.lib.models.device import PartitionTable, SectorSize, Size, Unit  # type: ignore

    class _StubDeviceInfo:
        def __init__(self, path: Path) -> None:
            self.model = "STUB (offline validation)"
            self.path = path
            self.type = "disk"
            self.total_size = Size(TARGET_DISK_BYTES, Unit.B, SectorSize(512, Unit.B))
            self.free_space_regions = []
            self.sector_size = SectorSize(512, Unit.B)
            self.read_only = False
            self.dirty = False

    class _StubDisk:
        def __init__(self, path: Path) -> None:
            self.device = str(path)
            self.type = "gpt"

    class _StubDevice:
        def __init__(self, path: Path) -> None:
            self.device_info = _StubDeviceInfo(path)
            self.disk = _StubDisk(path)

    device_handler.get_device = lambda path, *a, **kw: _StubDevice(Path(str(path)))
    # Assume GPT regardless of how the validator host booted; this profile is
    # GPT-only (ESP + LUKS + btrfs).
    device_handler._partition_table = PartitionTable.GPT

    return ArchConfig, ModificationStatus


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("profile", nargs="?", default=HERE / "user_configuration.json")
    args = ap.parse_args()

    profile_path = Path(args.profile).resolve()
    if not profile_path.is_file():
        die(f"profile not found: {profile_path}")

    raw = profile_path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        die(f"{profile_path} is not valid JSON: {exc}")

    ArchConfig, ModificationStatus = load_archinstall()

    # `from_config` needs an `Arguments` object for two fields only
    # (`skip_boot`, and the deprecated uki fallback). Everything else is
    # driven by the profile itself.
    stub_args = SimpleNamespace(skip_boot=False)

    # archinstall reads the encryption password from the same merged mapping
    # that --creds provides.
    #
    # NOTE the sentinel below. `DiskEncryption.parse_arg` returns None when the
    # password is falsy, which means a profile whose creds file lacks
    # `encryption_password` is installed *unencrypted* with no error. Passing a
    # non-empty sentinel here is what makes the encryption block parse, so this
    # validator can actually assert on it.
    creds_path = profile_path.parent / "user_credentials.json.example"
    if not creds_path.is_file():
        die(f"credentials example missing: {creds_path}")
    creds = json.loads(creds_path.read_text(encoding="utf-8"))

    # archinstall merges the --creds document into the profile document before
    # parsing (ArchConfigHandler._parse_config). Emulate that so the merged
    # result is what actually gets validated.
    merged = {**data, **creds}

    # Third silent-drop footgun: DiskEncryption.parse_arg returns None when the
    # password is falsy, so a creds file without `encryption_password` installs
    # the whole root/swap/home set *unencrypted* with no error raised.
    merged["encryption_password"] = merged.get("encryption_password") or SENTINEL_PASSWORD

    # Fourth: User.parse_arguments skips entries with no password, so a creds
    # file that omits it installs with no unprivileged account at all.
    merged["users"] = [
        {**u, "enc_password": u.get("enc_password") or SENTINEL_PASSWORD}
        for u in merged.get("users", [])
    ]

    try:
        cfg = ArchConfig.from_config(merged, stub_args)
    except SystemExit as exc:
        die(f"archinstall rejected the profile (exit {exc.code})")
    except Exception as exc:  # noqa: BLE001 - surface any parser rejection verbatim
        die(f"archinstall rejected the profile: {type(exc).__name__}: {exc}")

    ok("archinstall parsed the profile")

    # ---- decisions from docs/REFORMAT-XFCE.md ----
    if cfg.hostname != EXPECTED["hostname"]:
        die(f"hostname is {cfg.hostname!r}, expected {EXPECTED['hostname']!r}")
    ok(f"hostname = {cfg.hostname}")

    if cfg.kernels != EXPECTED["kernels"]:
        die(f"kernels are {cfg.kernels!r}, expected {EXPECTED['kernels']!r}")
    ok(f"kernels = {cfg.kernels}")

    if cfg.swap is None or not cfg.swap.enabled:
        die("swap (zram) must be enabled")
    if cfg.swap.algorithm.value != EXPECTED["swap_algorithm"]:
        die(f"zram algorithm is {cfg.swap.algorithm.value!r}, expected {EXPECTED['swap_algorithm']!r}")
    ok(f"zram enabled, algorithm = {cfg.swap.algorithm.value}")

    disk = cfg.disk_config
    if disk is None:
        die("disk_config did not parse")
    if disk.config_type.value != "manual_partitioning":
        die(f"config_type is {disk.config_type.value!r}, expected manual_partitioning")
    ok("disk_config = manual_partitioning")

    boot = cfg.bootloader_config
    if boot is None or boot.bootloader.value != EXPECTED["bootloader"]:
        got = boot.bootloader.value if boot else None
        die(f"bootloader is {got!r}, expected {EXPECTED['bootloader']!r}")
    if boot.uki != EXPECTED["uki"]:
        die(f"uki is {boot.uki}, expected {EXPECTED['uki']}")
    if boot.removable != EXPECTED["removable"]:
        die(f"removable is {boot.removable}, expected {EXPECTED['removable']}")
    ok(f"bootloader = {boot.bootloader.value}, uki={boot.uki}, removable={boot.removable}")

    # encryption covers swap + root + home, never the ESP
    enc = disk.disk_encryption
    if enc is None:
        die("disk_encryption is missing; root/swap/home must be LUKS2")
    if enc.encryption_type.value != "luks":
        die(f"encryption_type is {enc.encryption_type.value!r}, expected luks")
    if len(enc.partitions) != EXPECTED["encrypted_partition_count"]:
        die(
            f"{len(enc.partitions)} partitions encrypted, "
            f"expected {EXPECTED['encrypted_partition_count']}"
        )
    ok(f"LUKS2 over {len(enc.partitions)} partitions")

    mods = disk.device_modifications
    if len(mods) != 1:
        die(f"{len(mods)} device_modifications, expected 1")
    mod = mods[0]
    if not mod.wipe:
        die("device_modifications.wipe is false; the profile must declare wipe:true")

    parts = mod.partitions
    if len(parts) != 4:
        die(f"{len(parts)} partitions, expected 4 (EFI, swap, root, home)")

    for idx, part in enumerate(parts):
        want_fs = EXPECTED["partition_fs_types"][idx]
        got_fs = part.fs_type.value if part.fs_type else None
        if got_fs != want_fs:
            die(f"partition {idx + 1} fs_type is {got_fs!r}, expected {want_fs!r}")

        want_mnt = EXPECTED["partition_mountpoints"][idx]
        got_mnt = str(part.mountpoint) if part.mountpoint else None
        if got_mnt != want_mnt:
            die(f"partition {idx + 1} mountpoint is {got_mnt!r}, expected {want_mnt!r}")

        want_flags = sorted(EXPECTED["partition_flags"][idx])
        got_flags = sorted(f.description for f in part.flags)
        if got_flags != want_flags:
            die(f"partition {idx + 1} flags are {got_flags!r}, expected {want_flags!r}")

        if part.status != ModificationStatus.Create:
            die(f"partition {idx + 1} status is {part.status}, expected create")
    ok("partition table = ESP(fat32) + swap(linux-swap) + root(btrfs) + home(btrfs)")

    root_part, home_part = parts[2], parts[3]
    got_root_subvols = [s.name.name if hasattr(s.name, "name") else str(s.name) for s in root_part.btrfs_subvols]
    if got_root_subvols != EXPECTED["root_subvolumes"]:
        die(f"root subvolumes are {got_root_subvols!r}, expected {EXPECTED['root_subvolumes']!r}")
    got_home_subvols = [s.name.name if hasattr(s.name, "name") else str(s.name) for s in home_part.btrfs_subvols]
    if got_home_subvols != EXPECTED["home_subvolumes"]:
        die(f"home subvolumes are {got_home_subvols!r}, expected {EXPECTED['home_subvolumes']!r}")
    ok(f"root subvolumes = {got_root_subvols}")
    ok(f"home subvolumes = {got_home_subvols}")

    for label, part in (("root", root_part), ("home", home_part)):
        if list(part.mount_options) != EXPECTED["btrfs_mount_options"]:
            die(
                f"{label} mount_options are {list(part.mount_options)!r}, "
                f"expected {EXPECTED['btrfs_mount_options']!r}"
            )
    ok(f"btrfs mount_options = {EXPECTED['btrfs_mount_options']}")

    # ESP must carry the ESP partition GUID so systemd-boot finds itself
    esp_flags = {f.description for f in parts[0].flags}
    if "esp" not in esp_flags:
        die("ESP partition is missing the 'esp' flag")

    # KNOWN archinstall 4.x BUG (verified against 4.0):
    #   SubvolumeModification.parse_args() stores `name` as a plain str, while
    #   is_default_root() compares it against Path('@'). For any profile loaded
    #   with --config that comparison is always False, so
    #   has_default_btrfs_vols() returns False and DiskLayoutConfiguration
    #   silently discards `btrfs_options` -- including snapshot_config.
    #   The interactive menu path is unaffected because its subvolume names come
    #   from `btrfs subvolume list` as Path objects.
    #
    # We therefore do NOT put btrfs_options in the profile. The snapshot
    # packages are requested explicitly and install-scripts/app/07_snapshots.sh
    # does the real configuration. Assert that arrangement instead of pretending
    # the key works.
    if "btrfs_options" in data["disk_config"]:
        die(
            "disk_config.btrfs_options is a no-op for --config installs "
            "(archinstall drops it); remove it and configure snapshots in "
            "install-scripts/app/07_snapshots.sh"
        )
    if disk.btrfs_options is not None:
        die("disk.btrfs_options unexpectedly populated; re-check the archinstall version")
    missing = [pkg for pkg in EXPECTED["snapshot_packages"] if pkg not in cfg.packages]
    if missing:
        die(f"snapshot packages missing from `packages`: {missing}")
    ok(f"snapshot packages requested explicitly: {EXPECTED['snapshot_packages']}")

    # no DE profile, no graphics driver: install-scripts/app owns those
    prof = cfg.profile_config
    if prof is not None and prof.profile is not None:
        die("profile_config.profile must be empty; the DE is installed by install-scripts")
    if prof is not None and prof.gfx_driver is not None:
        die("profile_config.gfx_driver must be empty; nvidia-open-dkms is installed by app/02")
    ok("no DE profile, no archinstall gfx driver")

    # Users live in the creds document under a TOP-LEVEL `users` key, not inside
    # `auth_config`: AuthenticationConfiguration.parse_arg only reads u2f_config
    # and root_enc_password, and archinstall's own safe_config() never writes
    # users into the profile at all.
    if "auth_config" in data and "users" in data["auth_config"]:
        die("users must be a top-level key of the creds file, not auth_config.users")
    if "users" in data:
        die("the committed profile must not declare users; they belong in --creds")
    if "users" not in creds:
        die("creds example must declare a top-level `users` array")
    users = cfg.auth_config.users if cfg.auth_config else []
    if len(users) != 1 or users[0].username != "autcir":
        got = [u.username for u in users]
        die(f"users are {got!r}, expected ['autcir']")
    if sorted(users[0].groups) != sorted(EXPECTED["user_groups"]):
        die(f"user groups are {sorted(users[0].groups)!r}, expected {sorted(EXPECTED['user_groups'])!r}")
    if not users[0].sudo:
        die("user autcir must have sudo")
    ok("user autcir: sudo + wheel,storage,power,audio,video,network,input")

    # credentials must never be committed
    for forbidden in ("!password", "enc_password", "root_enc_password", "encryption_password", "!root-password"):
        if forbidden in raw:
            die(f"profile contains credential key {forbidden!r}; keep it in --creds only")
    ok("no credentials in the committed profile")

    for required in ("encryption_password", "!root-password", "users"):
        if required not in creds:
            die(f"creds example is missing {required!r}")
    if not all(u.get("username") and (u.get("!password") or u.get("enc_password")) for u in creds["users"]):
        die("every creds user needs a username and a password, or archinstall drops it")
    ok("creds example declares encryption_password, root password and users")

    for required in ("mkinitcpio", "sd-encrypt"):
        if not any(required in c for c in cfg.custom_commands):
            die(f"custom_commands must configure {required!r} for LUKS-on-btrfs to boot")
    ok("custom_commands configure sd-encrypt + mkinitcpio hooks")

    print("\nPASS: profile matches archinstall's parser and docs/REFORMAT-XFCE.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())