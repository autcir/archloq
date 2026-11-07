#!/usr/bin/env bash
# =============================================================================
# loq-backup — borg repository on the external HDD
# =============================================================================
#   loq-backup.sh create    archive the configured paths, then prune
#   loq-backup.sh prune     apply retention only
#   loq-backup.sh list      show archives and their sizes
#   loq-backup.sh extract <archive> <destination>
#   loq-backup.sh status    is the disk mounted, is the repo reachable
#   loq-backup.sh check     borg check --verify on the repository
#
# Works as root (for the systemd timer) and as the user.
# =============================================================================

set -euo pipefail
MANAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHLOQ_ROOT="$(cd "$MANAGE_DIR/.." && pwd)"
export ARCHLOQ_ROOT
# shellcheck source=../install-scripts/lib/utils.sh
source "$ARCHLOQ_ROOT/install-scripts/lib/utils.sh"

require_config

user="${SUDO_USER:-${USER:-root}}"
target_home="$(getent passwd "$user" | cut -d: -f6)"
[[ -n "$target_home" ]] || target_home="/home/$user"

repo="$LOQ_BACKUP_MOUNT/borg/$LOQ_BORG_REPO_NAME"
passfile="$target_home/.config/loq/secrets/borg.passphrase"
keyfile="$target_home/.config/borg/${LOQ_BORG_REPO_NAME}.key"

# Only these are archived. Adding a broad /home sweep is how backups turn into
# multi-terabyte archives of node_modules.
PATHS=(
  "$target_home/Projects"
  "$target_home/Documents"
  "$target_home/Downloads"
  "$target_home/Desktop"
  "$target_home/Dotfiles"
  "$target_home/.config"
  "$target_home/.local/bin"
  "$target_home/.local/share/nvim"
  "$target_home/.ssh"
  "$target_home/.gnupg"
  "$target_home/.zshrc"
  "/etc/systemd/system"
  "/etc/ssh/sshd_config.d"
  "/etc/nftables.conf"
  "/etc/modprobe.d"
  "/etc/sysctl.d"
  "/etc/crypttab"
  "/etc/fstab"
  "/etc/legiond.conf"
  "/etc/intel-undervolt.conf"
  "/etc/timeshift"
)

# --exclude patterns, driven from LOQ_BACKUP_EXCLUDES
EXCLUDES=()
IFS=' ' read -r -a excludes_list <<<"${LOQ_BACKUP_EXCLUDES:-}"
for pattern in "${excludes_list[@]}"; do
  [[ -n "$pattern" ]] && EXCLUDES+=("--exclude=$pattern")
done
EXCLUDES+=(
  "--exclude=*.sock"
  "--exclude=.cache"
  "--exclude=node_modules"
  "--exclude=.venv"
  "--exclude=venv"
  "--exclude=target"
  "--exclude=dist"
  "--exclude=.git/objects/pack/tmp_*"
  "--exclude=*.pyc"
  "--exclude=.local/share/Trash"
  "--exclude=.mozilla/firefox/*/cache2"
  "--exclude=flatpak"
)

require_repo() {
  if [[ ! -d "$repo/data" ]]; then
    die "borg repository not found at $repo
       Is the backup disk attached? Check: lsblk -L $LOQ_BACKUP_LABEL"
  fi
  if [[ ! -r "$passfile" ]]; then
    die "borg passphrase not found at $passfile
       Automated backups need it. See docs/BACKUP.md."
  fi
}

cmd_create() {
  require_repo
  findmnt --target "$LOQ_BACKUP_MOUNT" >/dev/null 2>&1 \
    || die "$LOQ_BACKUP_MOUNT is not mounted. Attaching the disk is a deliberate act:
       this backup is not a mirror, it is the only copy of anything not on the NVMe."

  say "borg create -> $repo"
  export BORG_PASSPHRASE
  BORG_PASSPHRASE="$(cat "$passfile")"

  local existing=()
  local path
  for path in "${PATHS[@]}"; do
    [[ -e "$path" ]] && existing+=("$path")
  done
  ((${#existing[@]})) || die "none of the configured paths exist; nothing to back up"

  run borg create \
    --stats --list --show-rc --compression lz4 \
    "${EXCLUDES[@]}" \
    "$repo::archive-{now:%Y-%m-%dT%H:%M:%S}" \
    "${existing[@]}"

  cmd_prune
}

cmd_prune() {
  require_repo
  export BORG_PASSPHRASE
  BORG_PASSPHRASE="$(cat "$passfile")"
  say "pruning: ${LOQ_BACKUP_RETENTION_DAILY}d / ${LOQ_BACKUP_RETENTION_WEEKLY}w / ${LOQ_BACKUP_RETENTION_MONTHLY}m"
  run borg prune \
    --prefix 'archive-' \
    --show-rc --stats \
    --keep-daily "$LOQ_BACKUP_RETENTION_DAILY" \
    --keep-weekly "$LOQ_BACKUP_RETENTION_WEEKLY" \
    --keep-monthly "$LOQ_BACKUP_RETENTION_MONTHLY" \
    --keep-within 7d \
    "$repo"
}

cmd_list() {
  require_repo
  export BORG_PASSPHRASE
  BORG_PASSPHRASE="$(cat "$passfile")"
  run borg list --info "$repo"
}

cmd_status() {
  say "borg status"
  if findmnt --target "$LOQ_BACKUP_MOUNT" >/dev/null 2>&1; then
    ok "$LOQ_BACKUP_MOUNT is mounted from $(findmnt -no SOURCE --target "$LOQ_BACKUP_MOUNT")"
  else
    err "$LOQ_BACKUP_MOUNT is NOT mounted"
  fi
  if [[ -d "$repo/data" ]]; then
    ok "repository present at $repo"
    if [[ -r "$passfile" ]]; then
      ok "passphrase file present ($passfile)"
    else
      err "passphrase file missing ($passfile)"
    fi
    if [[ -r "$keyfile" ]]; then
      ok "client key present ($keyfile)"
    else
      err "client key missing ($keyfile)"
    fi
  else
    err "repository missing at $repo"
  fi
  if systemctl is-enabled --quiet loq-backup.timer 2>/dev/null; then
    ok "loq-backup.timer enabled; next run:"
    systemctl list-timers loq-backup.timer --no-pager 2>/dev/null | sed 's/^/        /'
  else
    warn "loq-backup.timer is not enabled"
  fi
}

cmd_check() {
  require_repo
  export BORG_PASSPHRASE
  BORG_PASSPHRASE="$(cat "$passfile")"
  say "borg check --verify (this reads the whole repository; it will take a while)"
  run borg check --verify "$repo"
}

cmd_extract() {
  (($# >= 3)) || die "usage: loq-backup.sh extract <archive> <path-inside-archive> <destination>"
  local archive="$1" inner="$2" dest="$3"
  require_repo
  export BORG_PASSPHRASE
  BORG_PASSPHRASE="$(cat "$passfile")"
  mkdir -p "$dest"
  say "extracting $inner from $archive"
  ( cd "$dest" && run borg extract "$repo::$archive" "$inner" )
  ok "extracted to $dest"
}

action="${1:-status}"
shift || true
case "$action" in
  create) cmd_create ;;
  prune)  cmd_prune ;;
  list)   cmd_list ;;
  status) cmd_status ;;
  check)  cmd_check ;;
  extract) cmd_extract "$@" ;;
  *) die "unknown action '$action' (create|prune|list|status|check|extract)" ;;
esac
