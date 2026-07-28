#!/usr/bin/env bash
# 10-gtk-catppuccin.sh — Installa e attiva Catppuccin GTK theme (Mocha, accent Blue) per GTK3/GTK4.
# Garantisce coerenza visiva tra app Qt (Kvantum) e app GTK (Firefox, gedit, ecc.).
# Idempotente: skip se già installato.
set -euo pipefail

say()  { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

AUR_HELPER="$(cat /tmp/loq-dotfiles-aur-helper 2>/dev/null || echo yay)"
GTK_THEME="Catppuccin-Mocha-Standard-Blue-Dark"

# --- 1. Installa catppuccin-gtk-theme-mocha (AUR) ---------------------------
say "Installazione catppuccin-gtk-theme-mocha"
if pacman -Q catppuccin-gtk-theme-mocha >/dev/null 2>&1; then
  skip "catppuccin-gtk-theme-mocha già installato"
else
  "$AUR_HELPER" -S --needed --noconfirm catppuccin-gtk-theme-mocha 2>/dev/null \
    && ok "catppuccin-gtk-theme-mocha installato" \
    || {
      warn "AUR fallito. Tentativo clone manuale da GitHub..."
      TMP=$(mktemp -d)
      git clone --depth 1 "https://github.com/catppuccin/gtk" "$TMP/catppuccin-gtk" 2>/dev/null || true
      if [ -d "$TMP/catppuccin-gtk" ]; then
        THEME_DIR="$HOME/.themes/$GTK_THEME"
        mkdir -p "$THEME_DIR"
        cp -r "$TMP/catppuccin-gtk/themes/mocha/"* "$THEME_DIR/" 2>/dev/null || true
        ok "GTK theme copiato manualmente → $THEME_DIR"
      fi
      rm -rf "$TMP"
    }
fi

# --- 2. Cerca il nome esatto del tema installato ----------------------------
say "Individuazione nome tema GTK Catppuccin Mocha Blue"
FOUND_THEME=""
for d in /usr/share/themes ~/.themes; do
  if [ -d "$d" ]; then
    for _c in "$d"/*[Cc]atppuccin*[Mm]ocha*[Bb]lue*; do
      [ -e "$_c" ] || continue
      FOUND_THEME=$(basename "$_c")
      break
    done
    [ -n "$FOUND_THEME" ] && break
  fi
done
if [ -z "$FOUND_THEME" ]; then
  # Fallback: cerca solo "Catppuccin-Mocha"
  for d in /usr/share/themes ~/.themes; do
    if [ -d "$d" ]; then
      for _c in "$d"/*[Cc]atppuccin*[Mm]ocha*; do
        [ -e "$_c" ] || continue
        FOUND_THEME=$(basename "$_c")
        break
      done
      [ -n "$FOUND_THEME" ] && break
    fi
  done
fi

if [ -n "$FOUND_THEME" ]; then
  ok "Tema trovato: $FOUND_THEME"
else
  FOUND_THEME="$GTK_THEME"
  warn "Tema non trovato automaticamente, uso: $FOUND_THEME (verifica l'installazione)"
fi

# --- 3. Applica GTK3 via gsettings -------------------------------------------
say "Applica GTK theme: $FOUND_THEME"
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "$FOUND_THEME" 2>/dev/null \
    && ok "gsettings GTK theme: $FOUND_THEME" || true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
fi

# --- 4. gtk-3.0/settings.ini (KDE Plasma usa questo) -----------------------
GTK3_CONF="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$(dirname "$GTK3_CONF")"
if [ -f "$GTK3_CONF" ]; then
  if grep -q "gtk-theme-name" "$GTK3_CONF"; then
    sed -i "s/gtk-theme-name=.*/gtk-theme-name=$FOUND_THEME/" "$GTK3_CONF"
  else
    echo "gtk-theme-name=$FOUND_THEME" >> "$GTK3_CONF"
  fi
  ok "gtk-3.0/settings.ini aggiornato"
fi

# --- 5. gtk-4.0/settings.ini ------------------------------------------------
GTK4_CONF="$HOME/.config/gtk-4.0/settings.ini"
mkdir -p "$(dirname "$GTK4_CONF")"
if [ -f "$GTK4_CONF" ]; then
  if grep -q "gtk-theme-name" "$GTK4_CONF"; then
    sed -i "s/gtk-theme-name=.*/gtk-theme-name=$FOUND_THEME/" "$GTK4_CONF"
  else
    echo "gtk-theme-name=$FOUND_THEME" >> "$GTK4_CONF"
  fi
  ok "gtk-4.0/settings.ini aggiornato"
fi

# --- 6. Applica dark mode preferita KDE -------------------------------------
kwriteconfig6 --file ~/.config/gtk-3.0/settings.ini --group Settings \
  --key gtk-application-prefer-dark-theme true 2>/dev/null || true

# --- 7. Aggiorna kdedefaults5 (KDE GTK config) ------------------------------
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file ~/.config/gtkrc-2.0 \
    --group GNOME --key gtk-theme-name "$FOUND_THEME" 2>/dev/null || true
fi

ok "10-gtk-catppuccin completa"
echo ""
echo "  GTK theme $FOUND_THEME applicato."
echo "  Riavvia le app GTK per vedere il nuovo tema."
echo "  In KDE System Settings: Appearance → GNOME/GTK Application Style → imposta $FOUND_THEME"
