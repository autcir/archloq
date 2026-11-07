#!/usr/bin/env bash
# =============================================================================
# 90 — post-install audit
# =============================================================================
# Assumes nothing. Reads the running system and compares it against
# config/loq.conf and archinstall/user_configuration.json, so drift between what
# was intended and what actually happened is visible before the first reboot.
#
# Reports; does not repair. Repairs belong in the script that owns the setting.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

problems=0
advisories=0

problem() { err "$*"; problems=$((problems + 1)); }
advisory() { note "$*"; advisories=$((advisories + 1)); }
pass() { ok "$*"; }

say "== 90 post-install audit =="

# -----------------------------------------------------------------------------
# Identity
# -----------------------------------------------------------------------------
if [[ "$(cat /etc/hostname 2>/dev/null)" == "$LOQ_HOSTNAME" ]]; then
  pass "hostname is $LOQ_HOSTNAME"
else
  problem "hostname is $(cat /etc/hostname 2>/dev/null || echo '?'), expected $LOQ_HOSTNAME"
fi

if id "$LOQ_USERNAME" >/dev/null 2>&1; then
  pass "user $LOQ_USERNAME exists"
  target_home="$(getent passwd "$LOQ_USERNAME" | cut -d: -f6)"
  missing_groups=""
  IFS=',' read -r -a want_groups <<<"$LOQ_USER_GROUPS"
  for grp in "${want_groups[@]}"; do
    id -nG "$LOQ_USERNAME" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp" || missing_groups+=" $grp"
  done
  if [[ -n "$missing_groups" ]]; then
    problem "$LOQ_USERNAME is missing group(s):$missing_groups"
  else
    pass "$LOQ_USERNAME has all required groups"
  fi
  if id -nG "$LOQ_USERNAME" | tr ' ' '\n' | grep -qx wheel; then
    if grep -qE '^%wheel\s+ALL=\(ALL(:ALL)?\)\s+NOPASSWD' /etc/sudoers 2>/dev/null; then
      problem "NOPASSWD is active for wheel; LOQ_SUDO_NOPASSWD is meant to be 0"
    else
      pass "wheel sudo requires a password"
    fi
  fi
else
  problem "user $LOQ_USERNAME does not exist -- archinstall dropped it (no password in --creds?)"
fi

# -----------------------------------------------------------------------------
# Partitions and mounts
#
# This is where a mismatched partition table shows up. The partition numbers come
# from loq.conf, which must match archinstall/user_configuration.json.
# -----------------------------------------------------------------------------
check_partition() {
  local dev="$1" role="$2" want_fs="$3"
  if [[ ! -b "$dev" ]]; then
    problem "$role: $dev does not exist"
    return
  fi
  local actual
  actual="$(blkid -s TYPE -o value "$dev" 2>/dev/null || echo unknown)"
  if [[ "$actual" == "$want_fs" ]]; then
    pass "$role: $dev is $want_fs"
  else
    problem "$role: $dev is '$actual', expected '$want_fs'"
  fi
}

check_partition "$LOQ_EFI_PARTITION" "ESP" vfat
if [[ -n "${LOQ_SWAP_PARTITION:-}" ]]; then
  check_partition "$LOQ_SWAP_PARTITION" "swap" crypto_LUKS
else
  advisory "no swap partition configured (studioloq ext4+zram, hibernate off)"
fi
# studioloq ext4 mode: root/home are ext4, not LUKS. Wipe mode expects crypto_LUKS.
if cryptsetup isLuks "$LOQ_ROOT_PARTITION" 2>/dev/null; then
  check_partition "$LOQ_ROOT_PARTITION" "root" crypto_LUKS
  check_partition "$LOQ_HOME_PARTITION" "home" crypto_LUKS
else
  check_partition "$LOQ_ROOT_PARTITION" "root" ext4
  check_partition "$LOQ_HOME_PARTITION" "home" ext4
  advisory "ext4 install detected; LUKS checks skipped (wipe layout not in use)"
fi

for dev in "$LOQ_ROOT_PARTITION" "$LOQ_HOME_PARTITION"; do
  if cryptsetup isLuks "$dev" 2>/dev/null; then
    pass "$dev is a LUKS container"
  elif ! enabled "${LOQ_ENABLE_SNAPSHOTS:-0}" && [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
    advisory "$dev is not encrypted (ext4 install, expected)"
  else
    problem "$dev is NOT encrypted"
  fi
done

if [[ "$(findmnt -no FSTYPE /)" == "btrfs" ]]; then
  pass "/ is btrfs"
elif [[ "$(findmnt -no FSTYPE /)" == "ext4" ]] && ! enabled "${LOQ_ENABLE_SNAPSHOTS:-0}"; then
  pass "/ is ext4 (snapshots disabled, expected on studioloq)"
else
  problem "/ is $(findmnt -no FSTYPE /), expected btrfs"
fi

# Root must be the @ subvolume by name, not by subvolid: a hard-coded subvolid
# silently breaks snapshot rollback.
if grep -qE '[[:space:]]/[[:space:]].*subvolid=' /etc/fstab; then
  problem "/etc/fstab pins a subvolid for /; snapshot rollback will not work"
elif grep -qE '[[:space:]]/[[:space:]].*subvol=@' /etc/fstab; then
  pass "/ is mounted by subvolume name (@)"
else
  advisory "/etc/fstab has no subvol=@ for /; check it looks right"
fi

# Every subvolume the profile declares must actually exist and be mounted.
have_btrfs=1
if have btrfs; then
  subvol_list="$(btrfs subvolume list / 2>/dev/null || true)"
else
  have_btrfs=0
  subvol_list=""
fi

check_subvol() {
  local name="$1" mnt="$2"
  # ext4 mode has no subvolumes; skip silently when snapshots are disabled.
  if [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]] && ! enabled "${LOQ_ENABLE_SNAPSHOTS:-0}"; then
    skip "no btrfs subvolumes on ext4 install ($name)"
    return
  fi
  if ((have_btrfs)) && ! printf '%s' "$subvol_list" | grep -qE " $name "; then
    problem "btrfs subvolume $name does not exist on /"
    return
  fi
  local src
  src="$(findmnt -no SOURCE --target "$mnt" 2>/dev/null || true)"
  if [[ "$src" == *"btrfs"* ]] || [[ "$src" == "/dev/mapper/root" ]]; then
    pass "$mnt is a btrfs mount"
  else
    problem "$mnt is not a btrfs mount (source: ${src:-none})"
  fi
}

check_subvol "@" "/"
check_subvol "@var" "/var"
check_subvol "@.timeshift" "/.timeshift"

# zram is the swap device; the LUKS swap partition is for hibernate only.
if findmnt -no SOURCE /dev/zram0 >/dev/null 2>&1 || swapon --show=NAME --noheadings | grep -q zram; then
  pass "zram is active"
else
  advisory "zram is not active; swap may be only the hibernate partition"
fi

# -----------------------------------------------------------------------------
# Encryption and boot (ext4+GRUB mode skips LUKS/crypttab; wipe mode enforces)
# -----------------------------------------------------------------------------
if cryptsetup isLuks "$LOQ_ROOT_PARTITION" 2>/dev/null; then
  if grep -q 'initramfs' /etc/crypttab 2>/dev/null; then
    pass "/etc/crypttab marks the LUKS devices initramfs"
  else
    problem "/etc/crypttab has no initramfs flag; systemd-boot cannot unlock root"
  fi
else
  advisory "ext4 install; no crypttab initramfs expected"
fi

keyfile_ref="$(grep -oE '/etc/cryptsetup-keys\.d/[a-z0-9._-]+' /etc/crypttab 2>/dev/null | head -1 || true)"
if [[ -n "$keyfile_ref" ]]; then
  if [[ -f "$keyfile_ref" ]]; then
    if [[ "$(stat -c '%a' "$keyfile_ref")" == "400" ]]; then
      pass "LUKS keyfile exists with mode 0400"
    else
      problem "$keyfile_ref has mode $(stat -c '%a' "$keyfile_ref"), expected 400"
    fi
  else
    problem "crypttab references $keyfile_ref but it does not exist"
  fi
else
  advisory "no /etc/cryptsetup-keys.d reference in crypttab"
fi

# Slot 0 must still hold the human passphrase: it is the recovery path.
for dev in "$LOQ_ROOT_PARTITION" "$LOQ_HOME_PARTITION"; do
  if cryptsetup luksDump "$dev" 2>/dev/null | grep -qE 'Slot: 0'; then
    pass "$dev has an active keyslot 0 (passphrase recoverable)"
  fi
done

if [[ -d /sys/firmware/efi/efivars ]]; then
  pass "booted via UEFI"
  if [[ -d /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c ]]; then
    for f in /sys/firmware/efi/efivars/SecureBoot-*; do
      [[ -r "$f" ]] || continue
      if [[ "$(tail -c 1 "$f" | od -An -tu1 | tr -d ' \n')" == "1" ]]; then
        problem "Secure Boot is enabled, but this setup ships unsigned kernels"
      fi
    done
  fi
else
  problem "did not boot via UEFI; systemd-boot will not be available"
fi

if [[ -f /boot/loader/loader.conf ]]; then
  pass "/boot/loader/loader.conf exists"
  if grep -q '^editor yes' /boot/loader/loader.conf; then
    advisory "the boot loader menu editor is enabled"
  fi
elif pacman -Qq grub >/dev/null 2>&1 || [[ -d /boot/grub ]]; then
  pass "GRUB in use; systemd-boot loader.conf not expected"
else
  problem "/boot/loader/loader.conf is missing; systemd-boot may not be installed"
fi

if cryptsetup isLuks "$LOQ_ROOT_PARTITION" 2>/dev/null; then
  if grep -qE 'sd-encrypt' /etc/mkinitcpio.conf; then
    pass "mkinitcpio has the sd-encrypt hook"
  else
    problem "mkinitcpio is missing the sd-encrypt hook; LUKS will not unlock at boot"
  fi
else
  advisory "ext4 install; sd-encrypt hook not expected"
fi

# -----------------------------------------------------------------------------
# Graphics
# -----------------------------------------------------------------------------
if pacman -Qq nvidia-open-dkms >/dev/null 2>&1; then
  pass "nvidia-open-dkms installed"
else
  problem "nvidia-open-dkms is not installed"
fi
for pkg in nvidia-dkms nvidia; do
  if pacman -Qq 2>/dev/null | grep -qx "$pkg"; then
    problem "$pkg is installed; this GPU (GB206M) has no closed-source driver"
  fi
done
if have nvidia-smi; then
  if nvidia-smi -L >/dev/null 2>&1; then
    pass "nvidia-smi sees: $(nvidia-smi -L | head -1)"
  else
    advisory "nvidia-smi cannot reach the driver yet; the module may need a rebuild (mkinitcpio -P + reboot)"
  fi
fi
if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
  ms="$(cat /sys/module/nvidia_drm/parameters/modeset)"
  if [[ "$ms" == "Y" ]]; then
    pass "nvidia_drm modeset=Y"
  else
    problem "nvidia_drm modeset=$ms; the display manager may not get a mode on the dGPU"
  fi
fi

# -----------------------------------------------------------------------------
# Power: exactly one owner
# -----------------------------------------------------------------------------
for pkg in tlp tlp-rdw; do
  if pacman -Qq "$pkg" >/dev/null 2>&1; then
    problem "$pkg is installed and fights power-profiles-daemon for the same knobs"
  fi
done
if systemctl is-enabled --quiet power-profiles-daemon; then
  pass "power-profiles-daemon enabled"
else
  problem "power-profiles-daemon is not enabled"
fi
for svc in thermald legiond; do
  if pacman -Qq "$svc" >/dev/null 2>&1; then
    if systemctl is-enabled --quiet "$svc"; then
      pass "$svc enabled"
    else
      advisory "$svc installed but not enabled"
    fi
  fi
done

# -----------------------------------------------------------------------------
# Desktop
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_DESKTOP:-0}"; then
  for svc in "${LOQ_DISPLAY_MANAGER}.service" NetworkManager.service; do
    if systemctl is-enabled --quiet "$svc"; then
      pass "$svc enabled"
    else
      problem "$svc is not enabled"
    fi
  done
  if pacman -Qq xfce4-goodies >/dev/null 2>&1; then
    advisory "xfce4-goodies is installed; this setup does not use it"
  fi
fi

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_FIREWALL:-0}"; then
  if nft list ruleset >/dev/null 2>&1; then
    pass "nftables ruleset loaded"
    if ! nft list chain inet loq_filter input 2>/dev/null | grep -q 'policy drop'; then
      problem "the loq_filter input chain does not default to drop"
    fi
  else
    problem "no nftables ruleset is loaded"
  fi
fi
if enabled "${LOQ_ENABLE_FAIL2BAN:-0}"; then
  if systemctl is-active --quiet fail2ban; then
    pass "fail2ban active"
  else
    advisory "fail2ban is not active"
  fi
fi

# -----------------------------------------------------------------------------
# Snapshots and backup
# -----------------------------------------------------------------------------
if enabled "${LOQ_ENABLE_SNAPSHOTS:-0}"; then
  if systemctl is-active --quiet btrfs-assistant; then
    pass "btrfs-assistant active"
  else
    problem "btrfs-assistant is not running; timeshift has no btrfs backend"
  fi
  if crontab -l 2>/dev/null | grep -q 'timeshift --create'; then
    pass "timeshift schedule present in root's crontab"
  else
    problem "no timeshift schedule in root's crontab"
  fi
fi
if enabled "${LOQ_ENABLE_BACKUP:-0}"; then
  if systemctl is-enabled --quiet loq-backup.timer; then
    pass "loq-backup.timer enabled"
  else
    problem "loq-backup.timer is not enabled"
  fi
  if findmnt --target "$LOQ_BACKUP_MOUNT" >/dev/null 2>&1; then
    pass "backup disk mounted at $LOQ_BACKUP_MOUNT"
  else
    advisory "backup disk not mounted right now; the timer requires it"
  fi
fi

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
echo
if ((problems > 0)); then
  err "$problems problem(s) found. Do not reboot until they are fixed."
  [[ -f "$ARCHLOQ_STATE_DIR/summary" ]] && { say "summary:"; sed 's/^/  /' "$ARCHLOQ_STATE_DIR/summary"; }
  exit 1
fi

if ((advisories > 0)); then
  note "$advisories advisory note(s); the install is usable."
else
  ok "no problems found"
fi
[[ -f "$ARCHLOQ_STATE_DIR/summary" ]] && { say "summary:"; sed 's/^/  /' "$ARCHLOQ_STATE_DIR/summary"; }
exit 0