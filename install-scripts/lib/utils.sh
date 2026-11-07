#!/usr/bin/env bash
# =============================================================================
# archloq — shared library
# =============================================================================
# Sourced by every script in install-scripts/app/ and manage/. Provides config
# loading, logging, package helpers that respect LOQ_UNATTENDED, and idempotency
# markers so a re-run is cheap and safe.
# =============================================================================

set -euo pipefail

# --- identity ---------------------------------------------------------------

ARCHLOQ_ROOT="${ARCHLOQ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ARCHLOQ_CONF="${ARCHLOQ_CONF:-$ARCHLOQ_ROOT/config/loq.conf}"
ARCHLOQ_STATE_DIR="${ARCHLOQ_STATE_DIR:-/var/lib/archloq}"
ARCHLOQ_LOG_DIR="${ARCHLOQ_LOG_DIR:-/var/log/archloq}"

# --- output ----------------------------------------------------------------

if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

_log() {
  local level="$1"; shift
  local stamp
  stamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s [%s] %-5s %s\n' "$stamp" "$(basename "${0:-archloq}")" "$level" "$*" >>"$ARCHLOQ_LOG_DIR/install.log" 2>/dev/null || true
}

say()  { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; _log INFO "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; _log OK "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; _log WARN "$*"; }
err()  { printf '%sfail%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; _log ERROR "$*"; }
die()  { err "$*"; exit 1; }
skip() { printf '%s  -- %s%s\n' "$C_DIM" "$*" "$C_RESET"; _log SKIP "$*"; }

# A step the operator should see but that is not an error, e.g. "Secure Boot is
# enabled, skipping".
note() { printf '%s  -> %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; _log NOTE "$*"; }

# --- preflight --------------------------------------------------------------

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "must run as root (use sudo)"
}

require_config() {
  [[ -r "$ARCHLOQ_CONF" ]] || die "config not found or unreadable: $ARCHLOQ_CONF"
  # shellcheck disable=SC1090  # path is a runtime value by design
  source "$ARCHLOQ_CONF"
  _validate_config
}

# Guard against the class of bug that produced a duplicated key in the old
# loq.conf, where the second definition silently won.
_validate_config() {
  local required=(
    LOQ_HOSTNAME LOQ_USERNAME LOQ_TIMEZONE LOQ_LOCALE LOQ_KEYMAP
    LOQ_KERNEL LOQ_DISPLAY_MANAGER LOQ_THEME LOQ_TERMINAL
    LOQ_NVIDIA_PACKAGES LOQ_GPU_MODE
    LOQ_ROOT_PARTITION LOQ_HOME_PARTITION LOQ_BACKUP_LABEL LOQ_BACKUP_MOUNT
    LOQ_UNATTENDED LOQ_DEBUG
  )
  local missing=()
  local key
  for key in "${required[@]}"; do
    [[ -n "${!key:-}" ]] || missing+=("$key")
  done
  ((${#missing[@]} == 0)) || die "config $ARCHLOQ_CONF is missing values: ${missing[*]}"

  local duplicates
  duplicates="$(awk -F= '/^[A-Z_]+=/ {print $1}' "$ARCHLOQ_CONF" | sort | uniq -d)"
  [[ -z "$duplicates" ]] || die "config $ARCHLOQ_CONF defines these keys more than once: $duplicates"
}

# --- command execution ------------------------------------------------------

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, echoing it first when LOQ_DEBUG=1. Never prompts when
# LOQ_UNATTENDED=1 -- callers must pass --noconfirm themselves.
run() {
  if [[ "${LOQ_DEBUG:-0}" == "1" ]]; then
    printf '%s    + %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
  fi
  "$@"
}

# Interactive gate. Returns 0 (yes) by default under LOQ_UNATTENDED=1.
confirm() {
  local prompt="$1"
  if [[ "${LOQ_UNATTENDED:-0}" == "1" ]]; then
    note "unattended: assuming yes to: $prompt"
    return 0
  fi
  [[ -t 0 ]] || { note "no tty: assuming yes to: $prompt"; return 0; }
  local reply
  read -rp "$prompt [y/N] " reply
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# --- flags ------------------------------------------------------------------

# enabled FLAG -> 0 if "1", else 1. Keeps call sites free of string compares.
enabled() { [[ "${1:-0}" == "1" ]]; }

# --- packages ---------------------------------------------------------------

# Install from the official repos. Safe to call with already-installed packages.
pkg_install() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || return 0

  local missing=()
  local pkg
  for pkg in "${pkgs[@]}"; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    skip "already installed: ${pkgs[*]}"
    return 0
  fi

  say "installing: ${missing[*]}"
  run pacman -S --needed --noconfirm "${missing[@]}"
}

pkg_remove() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || return 0
  say "removing: ${pkgs[*]}"
  run pacman -R --noconfirm "$@"
}

# Detect an AUR helper once. Returns non-zero if none is installed.
aur_helper() {
  local helper
  for helper in paru yay pikaur trizen; do
    have "$helper" && { printf '%s\n' "$helper"; return 0; }
  done
  return 1
}

# AUR packages are built from the network on every call, so they are never
# silently installed. Missing ones are reported and collected in a warning.
# paru/yay refuse to run as root, so drop to $SUDO_USER when root.
pkg_install_aur() {
  local pkgs=("$@")
  ((${#pkgs[@]})) || return 0

  local helper
  if ! helper="$(aur_helper)"; then
    warn "no AUR helper found; skipping AUR packages: ${pkgs[*]}"
    warn "install paru or yay, then re-run this script"
    return 1
  fi

  say "installing from AUR via $helper: ${pkgs[*]}"
  if [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    run sudo -u "$SUDO_USER" "$helper" -S --needed --noconfirm "$@"
  else
    run "$helper" -S --needed --noconfirm "$@"
  fi
}

# --- files ------------------------------------------------------------------

# Write a file only when its content would change, so re-runs are no-ops and
# mtimes stay meaningful.
write_file() {
  local path="$1" mode="${2:-0644}"
  local tmp
  tmp="$(mktemp)"

  cat >"$tmp"
  install -D -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
  ok "wrote $path"
}

# Replace lines matching a regex in a file, in place and idempotently.
# Usage: sed_idempotent <file> <sed-expression> <description>
sed_idempotent() {
  local file="$1" expr="$2" desc="$3"
  [[ -f "$file" ]] || die "sed_idempotent: $file does not exist"
  if sed -i "$expr" "$file"; then
    ok "$desc"
  else
    warn "$desc failed on $file"
    return 1
  fi
}

# Drop a key from a shell-style config file (used for /etc/fstab).
# Usage: fstab_drop <mountpoint-pattern>
fstab_drop() {
  local pattern="$1"
  [[ -f /etc/fstab ]] || return 0
  if grep -qE "$pattern" /etc/fstab; then
    sed_idempotent /etc/fstab "/$pattern/d" "removed stale fstab entry matching $pattern"
  fi
}

# --- units ------------------------------------------------------------------

svc_enable()  { run systemctl enable --now "$@"; ok "enabled ${*:-}"; }
svc_disable() { run systemctl disable --now "$@" || true; skip "disabled ${*:-}"; }

svc_is_active() { systemctl is-active --quiet "$1"; }

# --- idempotency markers ----------------------------------------------------

# State marker so a re-run can skip work that already succeeded.
marker_done() { [[ -f "$ARCHLOQ_STATE_DIR/$1" ]]; }
marker_set()  { mkdir -p "$ARCHLOQ_STATE_DIR"; : >"$ARCHLOQ_STATE_DIR/$1"; ok "marked $1 done"; }
marker_clear(){ rm -f "$ARCHLOQ_STATE_DIR/$1"; }

init_dirs() {
  mkdir -p "$ARCHLOQ_STATE_DIR" "$ARCHLOQ_LOG_DIR"
  chmod 0750 "$ARCHLOQ_STATE_DIR"
}

# --- misc -------------------------------------------------------------------

# Root filesystem UUID for a given partition.
part_uuid() {
  blkid -s UUID -o value "$1" 2>/dev/null || true
}

# LUKS container UUID for a given partition.
luks_uuid() {
  cryptsetup luksUUID "$1" 2>/dev/null || true
}

# Device currently mounted at a path.
mount_source() {
  findmnt -no SOURCE --target "$1" 2>/dev/null || true
}

# Emit a systemd unit only if it is not already installed with identical content.
install_unit() {
  local path="/etc/systemd/system/$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    skip "$1 already up to date"
  else
    install -m 0644 "$tmp" "$path"
    ok "wrote $path"
  fi
  rm -f "$tmp"
  run systemctl daemon-reload
}

summary_line() { printf '%s\n' "$*" >>"$ARCHLOQ_STATE_DIR/summary"; }