#!/usr/bin/env bash
# =============================================================================
# 09 — dotfiles
# =============================================================================
# Symlinks dotfiles/ into the user's ~/.config. Nothing is copied: a symlink is
# the only arrangement that makes `git pull` in dotfiles/ take effect without a
# second deploy step.
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

require_root
require_config
init_dirs

say "== 09 dotfiles =="

if ! enabled "${LOQ_DEPLOY_DOTFILES:-1}"; then
  skip "dotfiles deployment disabled by config"
  marker_set 09_dotfiles
  exit 0
fi

target_home="$(getent passwd "$LOQ_USERNAME" | cut -d: -f6)"
[[ -d "$target_home" ]] || die "home directory for $LOQ_USERNAME not found"

if [[ ! -x "$ARCHLOQ_ROOT/dotfiles/install.sh" ]]; then
  warn "dotfiles/install.sh is missing or not executable"
  exit 0
fi

say "deploying dotfiles to $target_home"
# Run as the user, not root: a script that writes to $HOME as root produces files
# root owns, which then breaks the user's own edits.
if runuser -u "$LOQ_USERNAME" -- env HOME="$target_home" XDG_CONFIG_HOME="$target_home/.config" \
  ARCHLOQ_ROOT="$ARCHLOQ_ROOT" "$ARCHLOQ_ROOT/dotfiles/install.sh"; then
  ok "dotfiles deployed"
else
  warn "dotfiles/install.sh failed; the desktop is usable but unstyled"
  warn "run it manually as $LOQ_USERNAME: $ARCHLOQ_ROOT/dotfiles/install.sh"
fi

chown -R "$LOQ_USERNAME:$LOQ_USERNAME" "$target_home/.config" 2>/dev/null || true

# Verify rather than assume. verify-catppuccin.sh reads the live xfconf state,
# so it fails if the deploy silently did nothing.
verifier="$ARCHLOQ_ROOT/dotfiles/scripts/verify-catppuccin.sh"
if [[ -x "$verifier" ]] && have xfconf-query; then
  if runuser -u "$LOQ_USERNAME" -- env HOME="$target_home" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    "$verifier"; then
    ok "theme verification passed"
  else
    warn "theme verification failed; see: $ARCHLOQ_ROOT/dotfiles/README.md"
  fi
else
  skip "theme verification needs an X session and xfconf-query; run it after logging in"
fi

summary_line "09: dotfiles deployed from $ARCHLOQ_ROOT/dotfiles"
marker_set 09_dotfiles
ok "09 dotfiles complete"
