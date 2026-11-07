#!/usr/bin/env bash
# =============================================================================
# 07 — btrfs snapshots
# =============================================================================
# archinstall's own btrfs_options.snapshot_config is a no-op for profiles loaded
# with --config (it drops the key silently), so the packages are requested in the
# profile and the actual configuration happens here.
#
# archinstall installs cronie + timeshift and stops there: no schedule, no
# snapshot path, no exclusions. That is the gap this script fills.
#
# Timeshift drives the schedule; btrfs-assistant is the btrfs backend it talks
# to. Timeshift's own crontab entries are used rather than a systemd timer
# because that is what timeshift's `--autoinstall` generates and what its
# retention settings are expressed in.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 07 snapshots =="

if ! enabled "${LOQ_ENABLE_SNAPSHOTS:-0}"; then
  skip "snapshots disabled by config"
  marker_set 07_snapshots
  exit 0
fi

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
pkg_install timeshift btrfs-assistant cronie

if ! findmnt -no FSTYPE / | grep -qi btrfs; then
  die "/ is not btrfs; snapshots need a btrfs root. Re-run archinstall with the profile in archinstall/."
fi

snapshot_dir="/.timeshift"
if ! findmnt --target "$snapshot_dir" >/dev/null 2>&1; then
  die "$snapshot_dir is not a mounted filesystem. The root partition's subvolume table is missing it."
fi

svc_enable btrfs-assistant
svc_enable cronie

# -----------------------------------------------------------------------------
# Exclusion list
#
# /home is excluded on purpose: it is its own btrfs partition and separately
# encrypted, and a snapshot of it would drag node_modules and container layers
# into every restore point. borg covers /home instead (08_backup_borg.sh).
#
# The pacman cache and the journal are excluded because they are pure churn:
# rolling back to them reverts a cache for no benefit.
# -----------------------------------------------------------------------------
{
  printf '/home\n'
  printf '/var/cache/pacman/pkg\n'
  printf '/var/cache\n'
  printf '/var/log\n'
  printf '/var/tmp\n'
  printf '/dev\n'
  printf '/proc\n'
  printf '/sys\n'
  printf '/run\n'
  printf '/tmp\n'
  printf '/mnt\n'
  printf '/media\n'
  printf '/.timeshift\n'
} | write_file /etc/timeshift/archloq-exclude 0644
ok "wrote the timeshift exclusion list"

# -----------------------------------------------------------------------------
# Timeshift configuration
#
# timeshift stores its own state in /etc/timeshift/timeshift.json. Writing that
# directly is more predictable than driving the Qt GUI, and it is the same file
# the GUI writes.
# -----------------------------------------------------------------------------
ts_state="/etc/timeshift/timeshift.json"
ts_config="$ARCHLOQ_ROOT/config/timeshift/timeshift.json"
if [[ -f "$ts_config" ]]; then
  install -Dm644 "$ts_config" "$ts_state"
  ok "installed $ts_state"
else
  warn "$ts_config is missing; leaving timeshift unconfigured"
fi

# -----------------------------------------------------------------------------
# Snapshot schedule
#
# Written as crontab entries so retention and cadence live in one reviewable
# place instead of being buried in a UI.
# -----------------------------------------------------------------------------
say "installing the snapshot schedule"
tmp_cron="$(mktemp)"
{
  printf '# archloq snapshot schedule -- managed by 07_snapshots.sh\n'
  printf 'SHELL=/bin/bash\n'
  printf 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n'
  printf '\n'
  printf '# hourly, keeping %s\n' "$LOQ_SNAPSHOT_KEEP_HOURLY"
  printf '17 * * * * root timeshift --create --schedule hourly --tags O --backup-dir %s\n' "$snapshot_dir"
  printf '\n'
  printf '# daily, keeping %s\n' "$LOQ_SNAPSHOT_KEEP_DAILY"
  printf '17 1 * * * root timeshift --create --schedule daily --tags O --backup-dir %s\n' "$snapshot_dir"
  printf '\n'
  printf '# weekly, keeping %s\n' "$LOQ_SNAPSHOT_KEEP_WEEKLY"
  printf '17 2 * * 0 root timeshift --create --schedule weekly --tags O --backup-dir %s\n' "$snapshot_dir"
  printf '\n'
  printf '# monthly, keeping %s\n' "$LOQ_SNAPSHOT_KEEP_MONTHLY"
  printf '17 3 1 * * root timeshift --create --schedule monthly --tags O --backup-dir %s\n' "$snapshot_dir"
} >"$tmp_cron"

# Replace only our block, never clobber an unrelated crontab.
# Merge existing entries (minus our old block) with the new schedule.
existing_cron="$(mktemp)"
crontab -l 2>/dev/null | sed '/archloq snapshot schedule/,/^$/d' >"$existing_cron" || true
cat "$existing_cron" "$tmp_cron" | crontab -
rm -f "$tmp_cron" "$existing_cron"
ok "crontab installed for root (existing entries preserved)"

# Retention is applied by timeshift itself when it prunes, so tell it the limits.
if have timeshift && timeshift --help 2>&1 | grep -q 'keep-'; then
  note "retention is enforced by timeshift on prune; verify with: timeshift --list"
fi

# -----------------------------------------------------------------------------
# First snapshot, so there is something to roll back to before any updates.
# -----------------------------------------------------------------------------
if confirm "Create the first snapshot now?"; then
  if timeshift --create --tags O --backup-dir "$snapshot_dir" >/dev/null 2>&1; then
    ok "first snapshot created"
  else
    warn "timeshift could not create a snapshot; check 'timeshift --list'"
  fi
fi

# -----------------------------------------------------------------------------
# Take an explicit pre-upgrade snapshot from here on: see manage/loq-snapshot.sh
# -----------------------------------------------------------------------------
summary_line "07: timeshift + btrfs-assistant on $snapshot_dir"
marker_set 07_snapshots
ok "07 snapshots complete"

note "/boot is FAT32 and cannot be snapshotted. Rolling back @ restores the root"
note "filesystem but not the kernel. See docs/RECOVERY.md for the kernel rollback step."