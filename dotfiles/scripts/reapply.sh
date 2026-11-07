#!/usr/bin/env bash
# =============================================================================
# reapply — re-run the whole deploy
# =============================================================================
# Use after `git pull` in dotfiles/, or after editing the per-channel XML.
# Idempotent: install.sh replaces what it owns and leaves everything else alone.
# =============================================================================

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '==> %s\n' "$*"; }

say "reapplying dotfiles"
"$DOTFILES_ROOT/install.sh"

# Re-running a package installer as a side effect of a dotfile update is not
# what this script is for, so only the live-session steps are replayed.
keybinds="$DOTFILES_ROOT/scripts/22-keybindings.sh"
if [[ -x "$keybinds" ]]; then
  if [[ -n "${DISPLAY:-}" ]]; then
    "$keybinds" || printf '  warn  22-keybindings.sh reported a problem\n' >&2
  else
    printf '   --   skipping 22-keybindings.sh (no DISPLAY)\n'
  fi
fi

say "done. Log out and back in for the panel and theme changes to take full effect."
