#!/usr/bin/env bash
# =============================================================================
# loq-preflight — is it safe to wipe?
# =============================================================================
# Run this on the CURRENT system, before booting the installer. It answers one
# question: if /dev/nvme0n1 is erased right now, what is permanently lost?
#
#   ./manage/loq-preflight.sh            report only
#   ./manage/loq-preflight.sh --backup   report, then run a borg backup
#   ./manage/loq-preflight.sh --mount    mount the backup disk and report
# =============================================================================

set -euo pipefail
MANAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHLOQ_ROOT="$(cd "$MANAGE_DIR/.." && pwd)"
export ARCHLOQ_ROOT
# shellcheck source=../install-scripts/lib/utils.sh
source "$ARCHLOQ_ROOT/install-scripts/lib/utils.sh"

require_root
require_config

DO_BACKUP=0
DO_MOUNT=0
while (($#)); do
  case "$1" in
    --backup) DO_BACKUP=1; shift ;;
    --mount) DO_MOUNT=1; shift ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

risks=0
risk() { printf '%s  RISK%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*"; risks=$((risks + 1)); }
fine() { printf '%s  ok%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
info() { printf '%s  --    %s%s\n' "$C_DIM" "$*" "$C_RESET"; }

target="$LOQ_DISK_DEVICE"

say "== preflight: would erasing $target lose anything? =="

# -----------------------------------------------------------------------------
# Is this even the disk we think it is?
# -----------------------------------------------------------------------------
if [[ ! -b "$target" ]]; then
  die "$target does not exist on this machine. Check LOQ_DISK_DEVICE in config/loq.conf."
fi

disk_model="$(lsblk -dno MODEL "$target" 2>/dev/null | sed 's/[[:space:]]*$//' || echo unknown)"
disk_size="$(lsblk -b -dno SIZE "$target" 2>/dev/null || echo 0)"
disk_serial="$(lsblk -dno SERIAL "$target" 2>/dev/null | sed 's/[[:space:]]*$//' || true)"
expected_size=1024209543168

say "target disk"
info "device : $target"
info "model  : $disk_model"
info "size   : $disk_size bytes ($((disk_size / 1024 / 1024 / 1024)) GiB)"
[[ -n "$disk_serial" ]] && info "serial : $disk_serial"

if [[ "$disk_size" == "$expected_size" ]]; then
  fine "size matches the layout in archinstall/user_configuration.json"
else
  risk "size is $disk_size but the profile is built for $expected_size."
  risk "The partition offsets in the profile will not fit. Regenerate the profile with archinstall's menu first."
fi

# -----------------------------------------------------------------------------
# What is mounted from it?
# -----------------------------------------------------------------------------
say ""
say "what lives on $target"
mnt_src="$(findmnt -no SOURCE / 2>/dev/null || true)"
info "root source: ${mnt_src:-unknown}"
case "$mnt_src" in
  *crypt*|*/mapper/*) fine "root is on a LUKS container" ;;
  "") risk "cannot determine what is mounted at /" ;;
  *) risk "root does not appear to be encrypted (source: $mnt_src)" ;;
esac

part_list="$(lsblk -bno NAME,SIZE,FSTYPE,MOUNTPOINT "$target" | tail -n +2)"
while read -r name size fstype mnt; do
  [[ -n "$name" ]] || continue
  mnt="${mnt:-}"
  [[ "$name" =~ ^nvme ]] && continue
  dev="/dev/$name"
  if [[ -n "$mnt" ]]; then
    risk "$dev ($fstype) is mounted at $mnt -- erasing the disk unmounts it"
  else
    info "$dev ($fstype) not mounted"
  fi
done <<<"$part_list"

# -----------------------------------------------------------------------------
# Uncommitted work in git repositories
# -----------------------------------------------------------------------------
say ""
say "git repositories"
if have git; then
  uncommitted=()
  dirty_repos=0
  while IFS= read -r repo; do
    [[ -d "$repo/.git" ]] || continue
    status="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
      dirty_repos=$((dirty_repos + 1))
      changed="$(printf '%s\n' "$status" | wc -l)"
      uncommitted+=("$repo ($changed changed)")
    fi
  done < <(find /home -maxdepth 4 -name .git -type d -not -path '*/.cache/*' 2>/dev/null | sed 's|/\.git$||')

  if ((dirty_repos == 0)); then
    fine "no uncommitted changes in any repository under /home"
  else
    risk "$dirty_repos repository/repositories have uncommitted changes:"
    for repo in "${uncommitted[@]}"; do
      printf '        %s\n' "$repo"
    done
    info "commit them, or 'git bundle create backup.bundle --all' per repo, before wiping"
  fi

  # Unpushed commits are the quieter version of the same problem.
  say ""
  info "checking for unpushed commits"
  while IFS= read -r repo; do
    [[ -d "$repo/.git" ]] || continue
    branch="$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] || continue
    upstream="$(git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
    [[ -n "$upstream" ]] || {
      printf '        %s: branch %s has no upstream\n' "$repo" "$branch"
      continue
    }
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
    if [[ "$ahead" != "0" ]]; then
      printf '        %s: %s commit(s) ahead of %s\n' "$repo" "$ahead" "$upstream"
    fi
  done < <(find /home -maxdepth 4 -name .git -type d -not -path '*/.cache/*' 2>/dev/null | sed 's|/\.git$||')
else
  info "git is not installed; repository checks skipped"
fi

# -----------------------------------------------------------------------------
# SSH keys and GPG: small, unrecoverable, and painful to replace
# -----------------------------------------------------------------------------
say ""
say "credentials that cannot be regenerated"
for path in /home/*/.ssh; do
  [[ -d "$path" ]] || continue
  if [[ -n "$(ls -A "$path" 2>/dev/null)" ]]; then
    risk "$path contains $(find "$path" -maxdepth 1 -mindepth 1 | wc -l) file(s)"
  fi
done
for path in /home/*/.gnupg; do
  [[ -d "$path" ]] || continue
  if [[ -n "$(ls -A "$path" 2>/dev/null)" ]]; then
    risk "$path contains private GPG keys"
  fi
done
for path in /home/*/.config/keyrings; do
  [[ -d "$path" ]] || continue
  risk "$path contains a keyring"
done
if ! have gpg; then
  info "gpg is not installed; no GPG keys to worry about"
fi

# -----------------------------------------------------------------------------
# Anything large outside of the usual suspects
# -----------------------------------------------------------------------------
say ""
say "large directories under /home"
df_out="$(df -h /home 2>/dev/null | tail -1 || true)"
info "home usage: ${df_out:-unknown}"
du_top="$(du -xh --max-depth=1 /home 2>/dev/null | sort -rh | head -8 || true)"
if [[ -n "$du_top" ]]; then
  printf '%s\n' "$du_top" | sed 's/^/        /'
fi

# -----------------------------------------------------------------------------
# System state worth capturing before it is gone
# -----------------------------------------------------------------------------
say ""
say "system state that will not exist after the reinstall"
state_dir="/tmp/loq-preflight"
mkdir -p "$state_dir"
pacman -Qqe >"$state_dir/packages-explicit.txt" 2>/dev/null || true
pacman -Qq  >"$state_dir/packages-full.txt"     2>/dev/null || true
systemctl list-unit-files --state=enabled >"$state_dir/enabled-units.txt" 2>/dev/null || true
lsblk -f                                      >"$state_dir/lsblk.txt"        2>/dev/null || true
findmnt                                      >"$state_dir/findmnt.txt"      2>/dev/null || true
if have lsusb; then lsusb >"$state_dir/lsusb.txt" 2>/dev/null || true; fi
if have xrandr; then
  xrandr --listproviders >"$state_dir/randr-providers.txt" 2>/dev/null || true
  xrandr --verbose >"$state_dir/randr-verbose.txt" 2>/dev/null || true
fi
if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
  cat /sys/module/nvidia_drm/parameters/modeset >"$state_dir/nvidia-modeset.txt" 2>/dev/null || true
fi
if have cryptsetup; then
  for dev in "$LOQ_ROOT_PARTITION" "$LOQ_HOME_PARTITION" "$LOQ_SWAP_PARTITION"; do
    [[ -b "$dev" ]] || continue
    cryptsetup luksDump "$dev" 2>/dev/null | grep -E 'Version|UUID|Cipher|iter' \
      >>"$state_dir/luks-info.txt" 2>/dev/null || true
  done
  if cryptsetup luksHeaderBackup "$LOQ_ROOT_PARTITION" --header-backup-file "$state_dir/luks-header-root.bin" 2>/dev/null; then
    info "LUKS header for $LOQ_ROOT_PARTITION backed up to $state_dir/luks-header-root.bin"
  else
    info "could not back up the LUKS header (needs the passphrase)"
  fi
fi
info "system state captured in $state_dir -- copy this somewhere safe"

# -----------------------------------------------------------------------------
# The backup disk
# -----------------------------------------------------------------------------
say ""
say "external backup disk"

# A filesystem mounted twice in the same namespace, both writable and with
# different options, is a real corruption vector: writes through one path are not
# guaranteed to be visible through the other, and the journal is replayed by
# whichever instance is unmounted first. udisks2 and an fstab entry pointing at
# the same UUID produce exactly this.
backup_dev="$(blkid -L "$LOQ_BACKUP_LABEL" 2>/dev/null || true)"

if [[ -d "$LOQ_BACKUP_MOUNT" ]]; then
  src="$(mount_source "$LOQ_BACKUP_MOUNT")"
  all_mounts="$(findmnt -rn -o SOURCE,TARGET | awk -v s="$src" '$1==s {print $2}')"
  n="$(printf '%s\n' "$all_mounts" | grep -c . || true)"
  if ((n > 1)); then
    risk "${src:-the backup disk} is mounted $n times at once:"
    printf '%s\n' "$all_mounts" | sed 's/^/        /'
    risk "unmount the extra one before writing anything"
    risk "  sudo umount <path>   # keep only one"
    risk "  then: sudo systemctl daemon-reload"
  fi
fi

if [[ -n "$backup_dev" ]]; then
  fine "found $LOQ_BACKUP_LABEL on $backup_dev"
  if ((DO_MOUNT)); then
    mkdir -p "$LOQ_BACKUP_MOUNT"
    mountpoint -q "$LOQ_BACKUP_MOUNT" || run mount "$LOQ_BACKUP_MOUNT" 2>/dev/null \
      || run mount "$backup_dev" "$LOQ_BACKUP_MOUNT"
    fine "mounted at $LOQ_BACKUP_MOUNT"
  else
    info "currently: ${mnt:-unmounted}; pass --mount to mount it here"
  fi
  free_space="$(df -h --output=avail "$backup_dev" 2>/dev/null | tail -1 | tr -d ' ' || true)"
  info "free space: ${free_space:-unknown}"
else
  risk "no filesystem labelled '$LOQ_BACKUP_LABEL' is attached"
  info "Plug it in before running with --backup. It is where everything lands."
fi

if ((DO_BACKUP)); then
  say ""
  say "running a backup"
  "$MANAGE_DIR/loq-backup.sh" create || warn "the backup reported errors; see above"
fi

# -----------------------------------------------------------------------------
# Verdict
# -----------------------------------------------------------------------------
echo
if ((risks == 0)); then
  ok "no blockers found. Erasing $target should not lose data."
  ok ""
  say "Next: back up anyway, because preflight cannot see everything."
  say "  $MANAGE_DIR/loq-preflight.sh --backup"
  exit 0
fi

err "$risks risk(s) above. Read them before erasing $target."
echo
say "The external HDD is the safety net. Use it like this:"
say "  1. $MANAGE_DIR/loq-preflight.sh --mount --backup"
say "  2. boot the Arch ISO, verify 'lsblk' shows $target and the backup disk"
say "  3. archinstall with archinstall/user_configuration.json"
say "  4. docs/PARTITIONING.md has the manual partitioning reference"
exit 1