#!/usr/bin/env bash
# =============================================================================
# 08 — borg backup onto the external HDD
# =============================================================================
# The 1 TB ST1000LM035 (label EROSBACKUP, ext4) currently holds existing data and
# is mounted on demand by udisks2. This script makes it a managed backup target:
#
#   * mounted by UUID from /etc/fstab, so backups never depend on a desktop
#     session being open
#   * a borg repository on it, so the data is encrypted by borg even though the
#     underlying ext4 is not
#   * a systemd user timer for the daily run
#
# The repository passphrase is read at run time by manage/loq-backup.sh from a
# 0600 file inside LUKS2, and exported to borg for that command only. It is
# never baked into a unit file. See docs/BACKUP.md for what that does and does
# not protect against.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 08 borg backup =="

if ! enabled "${LOQ_ENABLE_BACKUP:-0}"; then
  skip "backup disabled by config"
  marker_set 08_backup_borg
  exit 0
fi

backup_dev="$(blkid -L "$LOQ_BACKUP_LABEL" 2>/dev/null || true)"
if [[ -z "$backup_dev" ]]; then
  die "no filesystem labelled '$LOQ_BACKUP_LABEL' found.
       Plug in the external disk, or set LOQ_BACKUP_LABEL in config/loq.conf to match
       what blkid actually reports (run: lsblk -f)."
fi
say "backup disk: $backup_dev ($(lsblk -no SIZE "$backup_dev" 2>/dev/null || echo '?'))"

# -----------------------------------------------------------------------------
# Mount it deterministically
# -----------------------------------------------------------------------------
mkdir -p "$LOQ_BACKUP_MOUNT"
backup_uuid="$(part_uuid "$backup_dev")"
if ! grep -qE "^UUID=${backup_uuid}[[:space:]]+${LOQ_BACKUP_MOUNT}[[:space:]]" /etc/fstab; then
  printf 'UUID=%s %s ext4 defaults,noatime,nodev,nosuid 0 2\n' "$backup_uuid" "$LOQ_BACKUP_MOUNT" >>/etc/fstab
  ok "added $LOQ_BACKUP_MOUNT to /etc/fstab"
fi

if ! findmnt --target "$LOQ_BACKUP_MOUNT" >/dev/null 2>&1; then
  run mount "$LOQ_BACKUP_MOUNT" || die "could not mount $LOQ_BACKUP_MOUNT"
fi
ok "mounted at $LOQ_BACKUP_MOUNT"

# Udisks2 would also offer this disk; having both paths means the same filesystem
# can be mounted twice. Leave udisks2 alone for interactive use, but make the
# scripted path authoritative.
if systemctl is-active --quiet udisks2; then
  note "udisks2 is running; the disk may also appear under /run/media/<user>/$LOQ_BACKUP_LABEL"
  note "the backup scripts use $LOQ_BACKUP_MOUNT exclusively"
fi

pkg_install borg

repo="$LOQ_BACKUP_MOUNT/borg/$LOQ_BORG_REPO_NAME"

# -----------------------------------------------------------------------------
# Repository
# -----------------------------------------------------------------------------
if [[ -f "$repo/config" || -d "$repo/data" ]]; then
  skip "borg repository already exists at $repo"
  if ! borg -r "$repo" info >/dev/null 2>&1; then
    warn "borg cannot read the existing repository; it may be encrypted with a different key"
  fi
else
  say "initialising a new borg repository (repokey = client-side key)"
  # repokey keeps the data encrypted even though ext4 on an external disk is not.
  if borg init --encryption repokey "$repo"; then
    ok "created $repo"
  else
    die "borg init failed"
  fi
fi

# -----------------------------------------------------------------------------
# Client key
#
# Losing this file means losing the repository. Copy it to the disk itself and to
# the encrypted home, and say so loudly.
# -----------------------------------------------------------------------------
keyfile="${LOQ_USERNAME}/.config/borg/${LOQ_BORG_REPO_NAME}.key"
mkdir -p "$(dirname "/home/$keyfile")"
if borg -r "$repo" key export "/home/$keyfile" 2>/dev/null; then
  chmod 0600 "/home/$keyfile"
  chown "$LOQ_USERNAME:$LOQ_USERNAME" "/home/$keyfile"
  ok "client key exported to /home/$keyfile"
  install -Dm600 "/home/$keyfile" "$LOQ_BACKUP_MOUNT/borg/${LOQ_BORG_REPO_NAME}.key" \
    || warn "could not copy the key onto the backup disk"
else
  warn "could not export the client key; if this is an existing repository the key may already be present"
fi

# -----------------------------------------------------------------------------
# Repository passphrase
# -----------------------------------------------------------------------------
secrets_dir="/home/$LOQ_USERNAME/.config/loq/secrets"
passfile="$secrets_dir/borg.passphrase"
mkdir -p "$secrets_dir"
chmod 0700 "$secrets_dir"

if [[ ! -f "$passfile" ]]; then
  if [[ "${LOQ_UNATTENDED:-0}" == "1" ]]; then
    warn "unattended and no $passfile exists; skipping automated backups"
    warn "create it manually: install -m600 /dev/urandom-like-passphrase $passfile"
  else
    say "the borg repository passphrase is needed to run backups unattended."
    read -rsp "Choose a borg repository passphrase: " new_pass; echo
    read -rsp "Confirm: " confirm_pass; echo
    if [[ "$new_pass" == "$confirm_pass" && -n "$new_pass" ]]; then
      printf '%s\n' "$new_pass" | write_file "$passfile" 0600
      chown -R "$LOQ_USERNAME:$LOQ_USERNAME" "$secrets_dir"
      ok "stored the passphrase at $passfile (mode 0600, inside LUKS2)"
    else
      warn "passphrases did not match; unattended backups will not be configured"
    fi
  fi
else
  skip "repository passphrase already present"
fi

# -----------------------------------------------------------------------------
# System timer (single owner). The old script created both a user timer and a
# root timer at 03:15, causing borg lock contention, and used ExecStop=prune
# which never runs after oneshot ExecStart. loq-backup.sh create already prunes.
# -----------------------------------------------------------------------------
install -m 0644 /dev/stdin /etc/systemd/system/loq-backup.service <<EOF
[Unit]
Description=archloq: borg backup to $LOQ_BACKUP_MOUNT
After=network-online.target local-fs.target
Wants=network-online.target
RequiresMountsFor=$LOQ_BACKUP_MOUNT

[Service]
Type=oneshot
ExecStart=$ARCHLOQ_ROOT/manage/loq-backup.sh create
TimeoutStartSec=4h

[Install]
WantedBy=timers.target
EOF

install -m 0644 /dev/stdin /etc/systemd/system/loq-backup.timer <<'EOF'
[Unit]
Description=archloq: daily borg backup (root timer)

[Timer]
OnCalendar=*-*-* 03:15:00
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

run systemctl daemon-reload
svc_enable loq-backup.timer

# -----------------------------------------------------------------------------
# First run, so the repository is not empty when you need it.
# -----------------------------------------------------------------------------
if confirm "Run a backup now?"; then
  if "$ARCHLOQ_ROOT/manage/loq-backup.sh" create; then
    ok "first backup complete"
  else
    warn "the first backup failed; fix the above before relying on this"
  fi
fi

summary_line "08: borg repo $repo, timer loq-backup.timer"
marker_set 08_backup_borg
ok "08 borg backup complete"

note "back up /home/$LOQ_USERNAME/.config/borg/$LOQ_BORG_REPO_NAME.key somewhere other"
note "than the backup disk. Without it the repository is unreadable."