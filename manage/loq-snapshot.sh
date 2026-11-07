#!/usr/bin/env bash
# =============================================================================
# loq-snapshot — explicit restore points
# =============================================================================
# Timeshift's cron schedule is hourly/daily/weekly/monthly, which is the wrong
# granularity for "I am about to change something and want to be able to undo
# it". These are labelled, on demand, and never automatically pruned.
#
#   loq-snapshot.sh pre            create a 'pre' snapshot
#   loq-snapshot.sh post           create a 'post' snapshot
#   loq-snapshot.sh pre-kernel     before anything that rebuilds DKMS
#   loq-snapshot.sh list           list manual snapshots
#   loq-snapshot.sh list auto      list scheduled ones
#   loq-snapshot.sh rollback <ts>  print the exact rollback commands
# =============================================================================

set -euo pipefail
MANAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHLOQ_ROOT="$(cd "$MANAGE_DIR/.." && pwd)"
export ARCHLOQ_ROOT
# shellcheck source=../install-scripts/lib/utils.sh
source "$ARCHLOQ_ROOT/install-scripts/lib/utils.sh"

require_root
require_config

backup_dir="/.timeshift"

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

need_timeshift() {
  have timeshift || die "timeshift is not installed. Run install-scripts/app/07_snapshots.sh"
  findmnt --target "$backup_dir" >/dev/null 2>&1 \
    || die "$backup_dir is not mounted; snapshots cannot be written"
}

create() {
  local tag="$1" why="$2"
  need_timeshift
  local stamp
  stamp="$(date '+%Y-%m-%d-%H%M%S')"
  say "creating snapshot $stamp-$tag"
  if timeshift --create --tags "$tag" --backup-dir "$backup_dir"; then
    ok "created $stamp-$tag"
    printf '%s\n' "$stamp-$tag" >>/var/lib/archloq/manual-snapshots
    if [[ -n "$why" ]]; then
      printf '        reason: %s\n' "$why"
    fi
  else
    die "timeshift could not create the snapshot"
  fi
}

list_which() {
  need_timeshift
  if [[ "${1:-manual}" == "auto" ]]; then
    timeshift --list --backup-dir "$backup_dir" || true
  else
    timeshift --list --backup-dir "$backup_dir" 2>/dev/null \
      | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' \
      | grep -E ' (pre|post|pre-kernel)$' || info "no manual snapshots yet"
  fi
}

rollback_hint() {
  local stamp="$1"
  cat <<EOF

Rolling back to ${stamp}

  # 1. Boot a live ISO -- do NOT roll back from the running system.
  # 2. cryptsetup luksOpen ${LOQ_ROOT_PARTITION}
  # 3. mount -o subvol=@snapshots ${LOQ_ROOT_PARTITION} /mnt/snapshots
  #    (the read-only snapshot subvolume under /.timeshift)
  # 4. find the snapshot whose name ends in ${stamp}
  # 5. mount -o subvol=<snapshot-id>,ro ${LOQ_ROOT_PARTITION} /mnt/root
  # 6. rsync -aAXH --delete /mnt/root/ /mnt/target/     # target = a fresh mount of @
  # 7. Also roll back the kernel: /boot is FAT32 and was NOT snapshotted.
  #    pacman -U /var/cache/pacman/pkg/linux-zen-<previous>.pkg.tar.zst

Full runbook: docs/RECOVERY.md
EOF
}

case "${1:-}" in
  pre)        create "pre" "${2:-manual checkpoint}" ;;
  post)       create "post" "${2:-after changes}" ;;
  pre-kernel) create "pre-kernel" "before a DKMS/kernel change" ;;
  list)       list_which manual ;;
  list-auto)  list_which auto ;;
  rollback)   (($# >= 2)) || die "usage: loq-snapshot.sh rollback <timestamp-suffix>"; rollback_hint "$2" ;;
  ""|-h|--help) usage ;;
  *) die "unknown action '${1}' (see --help)" ;;
esac
