#!/usr/bin/env bash
# 01-terminal.sh — ghostty (GPU terminal) + fastfetch con One Dark Pro.
# Idempotente: non sovrascrive config esistenti senza -f.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"
AUR_HELPER="$(cat /tmp/loq-dotfiles-aur-helper 2>/dev/null || echo yay)"

# --- ghostty (AUR) -----------------------------------------------------------
say "Installing ghostty (GPU-accelerated terminal)"
if command -v ghostty >/dev/null 2>&1; then
  skip "ghostty già installato"
else
  "$AUR_HELPER" -S --needed --noconfirm ghostty
  ok "installato ghostty"
fi

# --- fastfetch --------------------------------------------------------------
say "Checking fastfetch"
if pacman -Q fastfetch >/dev/null 2>&1; then
  skip "fastfetch già installato"
else
  sudo pacman -S --needed --noconfirm fastfetch
  ok "installato fastfetch"
fi

# --- ghostty config (One Dark Pro) ------------------------------------------
say "Installing ghostty config (One Dark Pro)"
GHOSTTY_DIR="$HOME/.config/ghostty"
mkdir -p "$GHOSTTY_DIR"
if [ -f "$GHOSTTY_DIR/config" ] && [ ! -f "$GHOSTTY_DIR/config.loq-bak" ]; then
  cp -a "$GHOSTTY_DIR/config" "$GHOSTTY_DIR/config.loq-bak"
fi
cp -af "$DOTROOT/config/ghostty/config" "$GHOSTTY_DIR/config"
ok "ghostty config → $GHOSTTY_DIR/config"

# --- fastfetch config (One Dark Pro) ----------------------------------------
say "Installing fastfetch config (One Dark Pro)"
FF_DIR="$HOME/.config/fastfetch"
mkdir -p "$FF_DIR"
cp -af "$DOTROOT/config/fastfetch/config.jsonc" "$FF_DIR/config.jsonc"
ok "fastfetch config → $FF_DIR/config.jsonc"

ok "01-terminal completa"
