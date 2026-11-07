#!/usr/bin/env bash
# =============================================================================
# dotfiles — deploy to ~/.config
# =============================================================================
# Everything is symlinked, never copied. That is the only arrangement where
# `git pull` in dotfiles/ takes effect without a second deploy step.
#
# Run as yourself, not as root: run by root it produces root-owned files in your
# home, which then breaks your own edits.
#
#   ./install.sh            deploy
#   ./install.sh --check    show what would change, deploy nothing
#   ./install.sh --remove   undo exactly what this created
# =============================================================================

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
MODE=deploy

while (($#)); do
  case "$1" in
    --check)  MODE=check; shift ;;
    --remove) MODE=remove; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ -d "$CONFIG_HOME" ]] || { printf 'no such directory: %s\n' "$CONFIG_HOME" >&2; exit 1; }

# DE-agnostic tools: straight symlink from dotfiles/config.
DIRECT=(
  bat btop cava fastfetch foot nvim starship zsh
  gtk-3.0 gtk-4.0 xsettings xbindkeys
  kvantum
)

# Xfce: the per-channel XML tree is copied, not symlinked, because xfconf
# rewrites those files in place on every settings change and a symlinked file
# would take the repo with it.
COPIED=(
  "config/xfce/xfce-perchannel-xml"
  "config/xfwm4/themes"
)

# ~/.xinitrc lives outside .config.
XINITRC_SRC="xinitrc"

installed_manifest() { printf '%s\n' "$CONFIG_HOME/.dotfiles-manifest"; }

link_target() {
  printf '%s/%s' "$CONFIG_HOME" "$1"
}

track() {
  installed_manifest >>"$2" 2>/dev/null || true
}

do_deploy() {
  local manifest
  manifest="$(installed_manifest)"
  : >"$manifest"

  printf 'deploying %s -> %s\n\n' "$DOTFILES_ROOT" "$CONFIG_HOME"

  local entry target existing
  for entry in "${DIRECT[@]}"; do
    src="$DOTFILES_ROOT/config/$entry"
    [[ -d "$src" ]] || continue
    target="$(link_target "$entry")"
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
      printf '  ok    %s (already linked)\n' "$entry"
      printf '%s\n' "$target" >>"$manifest"
      continue
    fi
    if [[ -e "$target" && ! -L "$target" ]]; then
      backup="${target}.dotfiles-backup.$(date +%s)"
      mv "$target" "$backup"
      printf '  moved %s -> %s\n' "$entry" "$(basename "$backup")"
    fi
    ln -sfn "$src" "$target"
    printf '  link  %s\n' "$entry"
    printf '%s\n' "$target" >>"$manifest"
  done

  for entry in "${COPIED[@]}"; do
    src="$DOTFILES_ROOT/$entry"
    [[ -d "$src" ]] || continue
    rel="${entry#config/}"
    target="$CONFIG_HOME/$rel"
    mkdir -p "$(dirname "$target")"
    # Replace wholesale: partial copies of an xfconf tree are how you get a
    # half-applied settings channel that nothing reports as wrong.
    [[ -e "$target" ]] && rm -rf "$target"
    cp -r "$src" "$target"
    printf '  copy  %s -> %s\n' "$entry" "$target"
    printf '%s\n' "$target" >>"$manifest"
  done

  if [[ -f "$DOTFILES_ROOT/$XINITRC_SRC" ]]; then
    if [[ -e "$HOME/.xinitrc" && ! -L "$HOME/.xinitrc" ]]; then
      mv "$HOME/.xinitrc" "$HOME/.xinitrc.dotfiles-backup.$(date +%s)"
    fi
    ln -sfn "$DOTFILES_ROOT/$XINITRC_SRC" "$HOME/.xinitrc"
    printf '  link  ~/.xinitrc\n'
    printf '%s\n' "$HOME/.xinitrc" >>"$manifest"
  fi

  printf '\nmanifest written to %s\n' "$manifest"
  printf 'next: run ~/.dotfiles/scripts/22-keybindings.sh and 21-panel.sh after logging in\n'
}

do_remove() {
  local manifest
  manifest="$(installed_manifest)"
  if [[ ! -f "$manifest" ]]; then
    printf 'no manifest at %s; nothing to undo\n' "$manifest"
    return 0
  fi
  printf 'removing what install.sh created:\n'
  local target
  while read -r target; do
    [[ -e "$target" || -L "$target" ]] || continue
    if [[ -L "$target" ]]; then
      rm -f "$target"
      printf '  unlink %s\n' "$target"
    else
      rm -rf "$target"
      printf '  rm    %s\n' "$target"
    fi
  done <"$manifest"
  rm -f "$manifest"
  printf '\ndone. Backups named *.dotfiles-backup.* were left in place.\n'
}

do_check() {
  local entry src target
  for entry in "${DIRECT[@]}"; do
    src="$DOTFILES_ROOT/config/$entry"
    [[ -d "$src" ]] || continue
    target="$(link_target "$entry")"
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
      printf '  ok        %s\n' "$entry"
    else
      printf '  would set %s\n' "$entry"
    fi
  done
  for entry in "${COPIED[@]}"; do
    src="$DOTFILES_ROOT/$entry"
    [[ -d "$src" ]] || continue
    rel="${entry#config/}"
    target="$CONFIG_HOME/$rel"
    if [[ -d "$target" ]]; then
      printf '  would replace %s\n' "$rel"
    else
      printf '  would copy %s\n' "$rel"
    fi
  done
}

case "$MODE" in
  deploy) do_deploy ;;
  remove) do_remove ;;
  check)  do_check ;;
esac
