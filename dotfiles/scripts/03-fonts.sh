#!/usr/bin/env bash
# 03-fonts.sh — JetBrains Mono Nerd Font + Font Awesome + Inter variable.
# Idempotente: pacman --needed salta già installati.
# Inter variable è il font UI eye-care raccomandato (leggero, coerente One Dark Pro).
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

# --- Nerd Fonts (pacman) ----------------------------------------------------
say "Installing Nerd Fonts via pacman"
PAC_FONTS=(
  ttf-jetbrains-mono-nerd
  ttf-meslo-nerd
  ttf-hack-nerd
)
sudo pacman -S --needed --noconfirm "${PAC_FONTS[@]}"

# --- Font Awesome (pacman) --------------------------------------------------
say "Installing Font Awesome"
sudo pacman -S --needed --noconfirm ttf-font-awesome

# --- Inter variable (pacman) eye-care UI font ------------------------------
say "Installing Inter variable (eye-care UI font)"
sudo pacman -S --needed --noconfirm ttf-inter
ok "Inter installato (font UI eye-care)"

# --- rebuild font cache -----------------------------------------------------
say "Rebuilding font cache"
fc-cache -fv >/dev/null 2>&1
ok "font cache aggiornato"

# --- verify -----------------------------------------------------------------
say "Verifying fonts"
if pacman -Q ttf-jetbrains-mono-nerd >/dev/null 2>&1; then
  ok "JetBrains Mono Nerd Font disponibile"
else
  echo "[ERR] JetBrains Mono Nerd Font non trovato" >&2
  exit 1
fi

ok "03-fonts completa"
