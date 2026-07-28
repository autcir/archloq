#!/usr/bin/env bash
# 04-theme-onedark.sh — Plasma color scheme + Kvantum + GTK + Aurorae, tutto One Dark Pro.
# Idempotente: copia file senza sovrascrivere backup esistenti.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"
AUR_HELPER="$(cat /tmp/loq-dotfiles-aur-helper 2>/dev/null || echo yay)"

# --- Kvantum (pacman) -------------------------------------------------------
say "Installing Kvantum"
sudo pacman -S --needed --noconfirm kvantum

# --- Plasma color scheme (One Dark Pro custom) -----------------------------
say "Installing Plasma color scheme (One Dark Pro)"
COLORS_DIR="$HOME/.local/share/color-schemes"
mkdir -p "$COLORS_DIR"
cp -af "$DOTROOT/config/plasma/OneDarkPro.colors" "$COLORS_DIR/OneDarkPro.colors"
ok "color scheme → $COLORS_DIR/OneDarkPro.colors"

# --- Kvantum theme (One Dark Pro) -------------------------------------------
say "Installing Kvantum theme (One Dark Pro)"
KV_DIR="$HOME/.config/Kvantum"
mkdir -p "$KV_DIR/OneDarkPro"
cp -af "$DOTROOT/config/kvantum/OneDarkPro"/* "$KV_DIR/OneDarkPro/"
ok "kvantum theme → $KV_DIR/OneDarkPro/"

# --- GTK theme (One Dark Pro) -----------------------------------------------
say "Installing GTK theme (One Dark Pro via AUR)"
GTK_THEME_DIR="$HOME/.themes"
mkdir -p "$GTK_THEME_DIR"
if [ -d "$GTK_THEME_DIR/OneDark-Pro" ] || [ -d "$GTK_THEME_DIR/OneDarkPro" ]; then
  skip "GTK One Dark Pro theme già presente"
else
  # Use gnome-look-compatible theme: Sweet-Dark or OneDark-Pro
  if pacman -Q groundwater-one-dark-gtk-theme >/dev/null 2>&1; then
    skip "AUR gtk theme già installato"
  else
    echo "  Download One Dark GTK theme..."
    TMP=$(mktemp -d)
    git clone --depth 1 "https://github.com/lucaJCS/OneDark-Pro-gtk" "$TMP/OneDark-Pro-gtk" 2>/dev/null || true
    if [ -d "$TMP/OneDark-Pro-gtk" ]; then
      cp -r "$TMP/OneDark-Pro-gtk" "$GTK_THEME_DIR/OneDark-Pro"
      ok "GTK theme → $GTK_THEME_DIR/OneDark-Pro"
    else
      # Fallback: Sweet-Dark via AUR
      "$AUR_HELPER" -S --needed --noconfirm sweet-gtk-theme 2>/dev/null || true
      skip "GTK theme fallback: Sweet-Dark (o installa manualmente)"
    fi
    rm -rf "$TMP"
  fi
fi

# --- Konsole profile (One Dark Pro) -----------------------------------------
say "Installing Konsole profile + colorscheme (One Dark Pro)"
KONSOLE_DIR="$HOME/.local/share/konsole"
mkdir -p "$KONSOLE_DIR"
cp -af "$DOTROOT/config/konsole/OneDarkPro.colorscheme" "$KONSOLE_DIR/OneDarkPro.colorscheme"
cp -af "$DOTROOT/config/konsole/OneDarkPro.profile" "$KONSOLE_DIR/OneDarkPro.profile"
ok "konsole profile → $KONSOLE_DIR/"

# --- Wallpaper ---------------------------------------------------------------
say "Installing wallpaper (One Dark Arch)"
WALL_DIR="$HOME/.local/share/wallpapers"
mkdir -p "$WALL_DIR"
cp -af "$DOTROOT/wallpapers/onedark-arch.jpeg" "$WALL_DIR/onedark-arch.jpeg"
ok "wallpaper → $WALL_DIR/onedark-arch.jpeg"

# --- Apply Plasma color scheme via plasma-apply-colorscheme ------------------
say "Applying Plasma color scheme"
plasma-apply-colorscheme OneDarkPro 2>/dev/null || skip "plasma-apply-colorscheme non disponibile (applica manualmente)"

# --- Apply Kvantum theme ----------------------------------------------------
say "Setting Kvantum theme"
kvantummanager --set OneDarkPro 2>/dev/null || skip "kvantummanager non disponibile (applica manualmente)"

ok "04-theme-onedark completa"
echo ""
echo "  Per applicare il wallpaper: plasma-apply-wallpaperimage $WALL_DIR/onedark-arch.jpeg"
echo "  O click destro sul desktop → Configure Desktop → Wallpaper"
