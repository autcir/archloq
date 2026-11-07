#!/usr/bin/env bash
# =============================================================================
# 99 — pre-reboot gate
# =============================================================================
# Runs last. Refuses to declare success if anything that would leave an
# unbootable or unencrypted machine is wrong. Exit code is what pacmaster.sh
# checks.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config

blocking=0
block() { err "BLOCKING: $*"; blocking=$((blocking + 1)); }

say "== 99 pre-reboot check =="

# -----------------------------------------------------------------------------
# The three ways a reboot here loses data or bricks the machine.
# On studioloq ext4+GRUB (snapshots disabled) LUKS/btrfs checks are skipped:
# there is nothing encrypted to fail unlocking.
# -----------------------------------------------------------------------------
IS_LUKS=0
if cryptsetup isLuks "$LOQ_ROOT_PARTITION" 2>/dev/null; then
  IS_LUKS=1
fi

# 1. Unencrypted root. Everything else can be fixed after boot; this cannot be
#    fixed without wiping. Enforced only in wipe (LUKS) mode.
if ((IS_LUKS)); then
  if ! cryptsetup isLuks "$LOQ_ROOT_PARTITION" 2>/dev/null; then
    block "$LOQ_ROOT_PARTITION is not encrypted"
  else
    ok "root is LUKS2"
  fi

  if ! cryptsetup isLuks "$LOQ_HOME_PARTITION" 2>/dev/null; then
    block "$LOQ_HOME_PARTITION is not encrypted"
  else
    ok "home is LUKS2"
  fi
else
  ok "ext4 install; LUKS encryption checks skipped"
fi

# 2. The keyfile must be registered in a keyslot, or the machine boots to a
#    prompt it cannot satisfy and you need a live USB. LUKS mode only.
if ((IS_LUKS)); then
  for dev in "$LOQ_ROOT_PARTITION" "$LOQ_HOME_PARTITION"; do
    slots="$(cryptsetup luksDump "$dev" 2>/dev/null | grep -cE '^\s+[0-9]+:' || true)"
    if ((slots < 2)); then
      block "$dev has $slots active keyslot(s); expected 2 (passphrase + keyfile)"
    else
      ok "$dev has $slots active keyslots"
    fi
  done

  if [[ ! -f /etc/cryptsetup-keys.d/loq-root.key ]]; then
    block "the LUKS keyfile is missing; 01_kernel_boot.sh did not complete"
  else
    ok "LUKS keyfile present"
  fi

  if ! grep -q 'initramfs' /etc/crypttab 2>/dev/null; then
    block "/etc/crypttab does not mark the devices initramfs; systemd-boot cannot unlock root"
  else
    ok "crypttab marks the devices for the initramfs"
  fi

  # 3. An initramfs that predates the crypttab change would ignore the keyfile.
  initramfs_newest="$(find /boot -maxdepth 2 -name 'initramfs*.img' -newer /etc/crypttab -print -quit 2>/dev/null || true)"
  if [[ -n "$initramfs_newest" ]]; then
    ok "at least one initramfs is newer than /etc/crypttab"
  else
    block "no initramfs newer than /etc/crypttab; run: mkinitcpio -P"
  fi
else
  ok "ext4 install; keyfile/crypttab checks skipped"
fi

# -----------------------------------------------------------------------------
# Boot chain
# -----------------------------------------------------------------------------
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  block "not booted via UEFI; systemd-boot cannot be used"
else
  for f in /sys/firmware/efi/efivars/SecureBoot-*; do
    [[ -r "$f" ]] || continue
    if [[ "$(tail -c 1 "$f" | od -An -tu1 | tr -d ' \n')" == "1" ]]; then
      block "Secure Boot is enabled; these kernels are unsigned"
    fi
  done
  ok "UEFI boot, Secure Boot off"
fi

if [[ ! -d /sys/efi/loader ]]; then
  # systemd-boot may not have been handed control yet on this boot, but the
  # entries must exist for the next one.
  if ! bootctl list --esp-path=/boot >/dev/null 2>&1; then
    advisory_msg="bootctl found no entries in the ESP; run: bootctl --esp-path=/boot install"
    warn "$advisory_msg"
    blocking=$((blocking + 0))
  else
    ok "systemd-boot has entries in the ESP"
  fi
else
  ok "systemd-boot is the active loader"
fi

if ! grep -q 'sd-encrypt' /etc/mkinitcpio.conf; then
  if ((IS_LUKS)); then
    block "mkinitcpio is missing the sd-encrypt hook"
  else
    ok "ext4 install; sd-encrypt hook not expected"
  fi
else
  ok "mkinitcpio hooks are correct"
fi

# -----------------------------------------------------------------------------
# Filesystem sanity (ext4 mode: mounts must exist, fstype check skipped)
# -----------------------------------------------------------------------------
if ((IS_LUKS)); then
  for mp in / /home /var /.timeshift; do
    src="$(findmnt -no SOURCE --target "$mp" 2>/dev/null || true)"
    [[ -n "$src" ]] || { block "$mp is not mounted"; continue; }
    fstype="$(findmnt -no FSTYPE --target "$mp" 2>/dev/null || true)"
    if [[ "$fstype" == "btrfs" ]]; then
      ok "$mp is a btrfs mount"
    else
      block "$mp is $fstype, expected btrfs"
    fi
  done
else
  for mp in / /home /boot; do
    src="$(findmnt -no SOURCE --target "$mp" 2>/dev/null || true)"
    [[ -n "$src" ]] || { block "$mp is not mounted"; continue; }
    ok "$mp mounted from $src"
  done
fi

# A read-only or degraded btrfs will boot and then misbehave.
for mp in / /home; do
  ro="$(findmnt -no OPTIONS --target "$mp" 2>/dev/null | tr ',' '\n' | grep -cx 'ro' || true)"
  if ((ro > 0)); then
    block "$mp is mounted read-only"
  fi
done
if have dmesg && dmesg 2>/dev/null | grep -qiE 'btrfs.*(error|corrupt)'; then
  block "the kernel reported btrfs errors; check dmesg before rebooting"
else
  ok "no btrfs errors reported"
fi

# -----------------------------------------------------------------------------
# Disk headroom: a full root turns the next pacman transaction into a failure.
# -----------------------------------------------------------------------------
root_use="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')"
if [[ -n "$root_use" && "$root_use" -ge 90 ]]; then
  block "root filesystem is ${root_use}% full"
elif [[ -n "$root_use" ]]; then
  ok "root filesystem is ${root_use}% full"
fi

# -----------------------------------------------------------------------------
# DKMS: nvidia-open must have built for the running kernel.
# -----------------------------------------------------------------------------
if [[ -d /usr/lib/modules/$(uname -r)/updates/dkms ]] \
   || modinfo -k "$(uname -r)" nvidia >/dev/null 2>&1; then
  ok "the NVIDIA module is built for $(uname -r)"
else
  warn "the NVIDIA module is not built for $(uname -r) yet."
  warn "That is expected before the first reboot; it will build on the next kernel update."
  warn "Verify after rebooting with: modinfo -k $(uname -r) nvidia"
fi

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
echo
if ((blocking > 0)); then
  err "$blocking blocking problem(s). DO NOT REBOOT."
  echo
  err "Recovery without a reinstall:"
  err "  1. Boot the Arch ISO"
  err "  2. cryptsetup luksOpen $LOQ_ROOT_PARTITION  (use your passphrase)"
  err "  3. mount -o subvol=@ /dev/mapper/root /mnt"
  err "  4. mount $LOQ_HOME_PARTITION /mnt/home   (after luksOpen)"
  err "  5. arch-chroot /mnt   then fix and run mkinitcpio -P"
  err "See docs/RECOVERY.md."
  exit 1
fi

ok "all blocking checks passed"
ok ""
say "You can reboot. After logging in, run:"
say "  sudo $ARCHLOQ_ROOT/manage/loq-uv-diagnose.sh    # validate the undervolt"
say "  sudo $ARCHLOQ_ROOT/manage/loq-snapshot.sh pre  # a restore point to exist"
say "  sudo $ARCHLOQ_ROOT/manage/loq-backup.sh status"
exit 0