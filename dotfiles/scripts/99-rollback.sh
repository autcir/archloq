#!/usr/bin/env bash
# =============================================================================
# 99-rollback — undo the deploy
# =============================================================================
# The previous version restored a Plasma profile from a konsave backup. konsave
# does not exist on Xfce, and more importantly a full-profile restore is the
# wrong granularity: it throws away unrelated configuration changes made since.
#
# This undoes exactly what install.sh created, tracked in its manifest, and
# leaves anything it did not create alone. Backups written by install.sh are kept
# rather than deleted.
# =============================================================================

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
manifest="$CONFIG_HOME/.dotfiles-manifest"

say() { printf '==> %s\n' "$*"; }
ok()  { printf '  ok  %s\n' "$*"; }
warn(){ printf '  warn %s\n' "$*" >&2; }

if [[ ! -f "$manifest" ]]; then
  warn "no manifest at $manifest -- install.sh has not run, or it was already rolled back"
  exit 0
fi

say "rolling back the dotfiles deploy"
removed=0
kept=0

while read -r target; do
  [[ -n "$target" ]] || continue
  if [[ -L "$target" ]]; then
    rm -f "$target"
    printf '  unlink %s\n' "$target"
    removed=$((removed + 1))
  elif [[ -d "$target" ]]; then
    rm -rf "$target"
    printf '  rm     %s\n' "$target"
    removed=$((removed + 1))
  else
    kept=$((kept + 1))
  fi
done <"$manifest"

rm -f "$manifest"

say "removed $removed item(s); $kept were already gone"
say "anything install.sh saved as *.dotfiles-backup.* was left in place."
say "to list them:  find $CONFIG_HOME -maxdepth 2 -name '*.dotfiles-backup.*'"
