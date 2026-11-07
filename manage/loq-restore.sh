#!/usr/bin/env bash
# =============================================================================
# loq-restore — get files back out of a borg archive
# =============================================================================
#   loq-restore.sh list                     archives, newest first
#   loq-restore.sh contents <archive>       what is inside one
#   loq-restore.sh extract <archive> <path-in-archive> [destination]
#   loq-restore.sh restore-home <archive>   put /home back on this machine
#   loq-restore.sh mount <archive>          browse an archive as a filesystem
#
# Assumes you can read the repository. See docs/RECOVERY.md for the case where
# you cannot, which is why the client key is backed up separately.
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
repo="$LOQ_BACKUP_MOUNT/borg/$LOQ_BORG_REPO_NAME"
passfile="$target_home/.config/loq/secrets/borg.passphrase"

load_passphrase() {
  [[ -r "$passfile" ]] || die "no borg passphrase at $passfile"
  BORG_PASSPHRASE="$(cat "$passfile")"
  export BORG_PASSPHRASE
}

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
  ""|-h|--help) usage; exit 0 ;;

  list)
    load_passphrase
    say "archives in $repo (newest last)"
    run borg list --sort-by mtime "$repo"
    ;;

  contents)
    (($# >= 2)) || die "usage: loq-restore.sh contents <archive>"
    load_passphrase
    run borg list "$repo::$2"
    ;;

  extract)
    (($# >= 3)) || die "usage: loq-restore.sh extract <archive> <path-in-archive> [destination]"
    load_passphrase
    dest="${4:-$PWD}"
    mkdir -p "$dest"
    say "extracting $3 from $2 into $dest"
    ( cd "$dest" && run borg extract "$repo::$2" "$3" )
    ok "done"
    ;;

  restore-home)
    (($# >= 2)) || die "usage: loq-restore.sh restore-home <archive>"
    load_passphrase
    say "This overwrites files in $target_home that are also in the archive."
    confirm "Continue?" || die "aborted"
    mkdir -p "$target_home"
    run borg extract "$repo::$2" "home/$user" --strip-components=0
    ok "home restored from $2"
    chown -R "$user:$user" "$target_home" 2>/dev/null || warn "could not fix ownership; check manually"
    ;;

  mount)
    (($# >= 2)) || die "usage: loq-restore.sh mount <archive>"
    load_passphrase
    mountpoint="$LOQ_BACKUP_MOUNT/borg-mount"
    mkdir -p "$mountpoint"
    say "mounting $2 at $mountpoint; press Ctrl-D then 'umount $mountpoint' to detach"
    run borg mount "$repo::$2" "$mountpoint"
    ;;

  *)
    die "unknown action '$1' (see --help)"
    ;;
esac
