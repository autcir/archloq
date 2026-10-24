#!/usr/bin/env bash
# 00-prereqs.sh — check prerequisite packages for the One Dark Pro rice.
# Idempotente: installa solo ciò che manca.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }


# --- pacman packages --------------------------------------------------------
PAC_PKGS=(git base-devel stow)
say "Checking pacman packages: ${PAC_PKGS[*]}"
for pkg in "${PAC_PKGS[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    skip "$pkg già installato"
  else
    sudo pacman -S --needed --noconfirm "$pkg"
    ok "installato $pkg"
  fi
done

# --- AUR helper check --------------------------------------------------------
say "Checking AUR helper (yay or paru)"
if command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
  ok "yay trovato"
elif command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
  ok "paru trovato"
else
  echo "[ERR] Nessun AUR helper trovato. Installa yay o paru." >&2
  exit 1
fi
echo "$AUR_HELPER" > /tmp/loq-dotfiles-aur-helper

# --- konsave (AUR) -----------------------------------------------------------
say "Checking konsave (Plasma profile backup)"
if pacman -Q konsave >/dev/null 2>&1; then
  skip "konsave già installato"
else
  "$AUR_HELPER" -S --needed --noconfirm konsave
  ok "installato konsave"
fi

ok "00-prereqs completa"
