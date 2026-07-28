#!/usr/bin/env bash
# 04-theme-catppuccin.sh — Plasma color scheme + Kvantum + GTK + Konsole, tutto Catppuccin Mocha Blue.
# Idempotente: copia file senza sovrascrivere backup esistenti.
# Nota: per i temi Aurorae + splash + look-and-feel completi, usa 08-themes-github.sh
set -euo pipefail

say()  { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTROOT="$(cd "$HERE/.." && pwd)"
AUR_HELPER="$(cat /tmp/loq-dotfiles-aur-helper 2>/dev/null || echo yay)"

# --- Kvantum (pacman) -------------------------------------------------------
say "Installing Kvantum"
sudo pacman -S --needed --noconfirm kvantum

# --- Plasma color scheme (Catppuccin Mocha Blue) ----------------------------
say "Installing Plasma color scheme (Catppuccin Mocha Blue)"
COLORS_DIR="$HOME/.local/share/color-schemes"
mkdir -p "$COLORS_DIR"
if [ -f "$COLORS_DIR/CatppuccinMochaBlue.colors" ]; then
  skip "CatppuccinMochaBlue.colors già presente"
else
  # Il color scheme viene installato da 08-themes-github.sh via catppuccin/kde
  warn "Esegui prima 08-themes-github.sh per installare CatppuccinMochaBlue.colors"
fi
plasma-apply-colorscheme CatppuccinMochaBlue 2>/dev/null \
  && ok "Color scheme CatppuccinMochaBlue applicato" \
  || skip "plasma-apply-colorscheme non disponibile (applica manualmente)"

# --- Kvantum theme (Catppuccin Mocha Blue) ----------------------------------
say "Setting Kvantum theme (Catppuccin Mocha Blue)"
KV_DIR="$HOME/.config/Kvantum"
if ls "$KV_DIR"/*[Mm]ocha* >/dev/null 2>&1; then
  KV_THEME=$(ls "$KV_DIR" | grep -iE 'mocha-blue|MochaBlue' | head -1)
  [ -z "$KV_THEME" ] && KV_THEME=$(ls "$KV_DIR" | grep -iE 'mocha' | head -1)
  kvantummanager --set "$KV_THEME" 2>/dev/null \
    && ok "Kvantum theme: $KV_THEME" \
    || skip "kvantummanager non disponibile (applica manualmente)"
else
  warn "Nessun tema Kvantum Mocha trovato in $KV_DIR — esegui 08-themes-github.sh prima"
fi

# --- GTK theme (Catppuccin Mocha) -------------------------------------------
say "Installing GTK theme (Catppuccin Mocha via AUR)"
GTK_DIR="$HOME/.themes"
mkdir -p "$GTK_DIR"
if pacman -Q catppuccin-gtk-theme-mocha >/dev/null 2>&1; then
  skip "catppuccin-gtk-theme-mocha già installato"
else
  "$AUR_HELPER" -S --needed --noconfirm catppuccin-gtk-theme-mocha 2>/dev/null \
    && ok "GTK theme catppuccin-gtk-theme-mocha installato" \
    || warn "Installa manualmente: $AUR_HELPER -S catppuccin-gtk-theme-mocha"
fi

# Applica GTK theme via gsettings
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha-Standard-Blue-dark" 2>/dev/null \
    && ok "GTK3 theme applicato (gsettings)" || true
fi

# gtk-3.0/settings.ini
GTK3_CONF="$HOME/.config/gtk-3.0/settings.ini"
if [ -f "$GTK3_CONF" ]; then
  if grep -q "gtk-theme-name" "$GTK3_CONF"; then
    sed -i 's/gtk-theme-name=.*/gtk-theme-name=Catppuccin-Mocha-Standard-Blue-dark/' "$GTK3_CONF"
    ok "gtk-3.0 theme aggiornato"
  fi
fi
# gtk-4.0/settings.ini
GTK4_CONF="$HOME/.config/gtk-4.0/settings.ini"
if [ -f "$GTK4_CONF" ]; then
  if grep -q "gtk-theme-name" "$GTK4_CONF"; then
    sed -i 's/gtk-theme-name=.*/gtk-theme-name=Catppuccin-Mocha-Standard-Blue-dark/' "$GTK4_CONF"
    ok "gtk-4.0 theme aggiornato"
  fi
fi

# --- Konsole profile (Catppuccin Mocha) -------------------------------------
say "Installing Konsole profile + colorscheme (Catppuccin Mocha)"
KONSOLE_DIR="$HOME/.local/share/konsole"
mkdir -p "$KONSOLE_DIR"
cp -af "$DOTROOT/config/konsole/CatppuccinMocha.colorscheme" "$KONSOLE_DIR/CatppuccinMocha.colorscheme"
cp -af "$DOTROOT/config/konsole/CatppuccinMocha.profile" "$KONSOLE_DIR/CatppuccinMocha.profile"
ok "Konsole profile → $KONSOLE_DIR/"

# --- Splash screen ----------------------------------------------------------
say "Attiva splash screen Catppuccin Mocha"
kwriteconfig6 --file ~/.config/ksplashrc --group KSplash --key Theme "Catppuccin-Mocha-Blue" 2>/dev/null \
  && ok "Splash screen: Catppuccin-Mocha-Blue" \
  || warn "kwriteconfig6 non disponibile"

# --- Cursor ------------------------------------------------------------------
say "Attiva cursor theme Catppuccin Mocha Blue"
kwriteconfig6 --file ~/.config/kcminputrc --group Mouse --key cursorTheme "catppuccin-mocha-blue-cursors" 2>/dev/null \
  && ok "Cursor: catppuccin-mocha-blue-cursors" \
  || warn "kwriteconfig6 non disponibile"

# --- Apply Plasma color scheme -----------------------------------------------
say "Applying Plasma color scheme"
plasma-apply-colorscheme CatppuccinMochaBlue 2>/dev/null \
  || skip "plasma-apply-colorscheme non disponibile (applica manualmente)"

# --- Reload KWin + Plasma ---------------------------------------------------
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

ok "04-theme-catppuccin completa"
echo ""
echo "  Catppuccin Mocha Blue attivo su:"
echo "    - Plasma color scheme (CatppuccinMochaBlue)"
echo "    - Kvantum application style"
echo "    - GTK3/GTK4 theme (Catppuccin-Mocha-Standard-Blue-dark)"
echo "    - Konsole (CatppuccinMocha colorscheme + profile)"
echo "    - Splash screen (Catppuccin-Mocha-Blue)"
echo "    - Cursor (catppuccin-mocha-blue-cursors)"
echo ""
echo "  Per completare il rice esegui anche:"
echo "    bash 08-themes-github.sh   # Aurorae + look-and-feel completo"
echo "    bash 09-icons-papirus.sh   # icon theme Papirus Catppuccin"
echo "    bash 11-wallpaper-catppuccin.sh  # wallpaper Catppuccin Mocha"
