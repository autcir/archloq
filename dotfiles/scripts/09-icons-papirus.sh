#!/usr/bin/env bash
# 09-icons-papirus.sh — Installa e attiva Papirus icon theme con folder color Catppuccin Mocha Blue.
# Papirus è il companion ufficiale della community Catppuccin per le icone su KDE.
# Idempotente: skip se già installato.
set -euo pipefail

say()  { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[WARN]\033[0m %s\n' "$*"; }

AUR_HELPER="$(cat /tmp/loq-dotfiles-aur-helper 2>/dev/null || echo yay)"

# --- 1. Papirus icon theme --------------------------------------------------
say "Installazione Papirus icon theme"
if pacman -Q papirus-icon-theme >/dev/null 2>&1; then
  skip "papirus-icon-theme già installato"
else
  sudo pacman -S --needed --noconfirm papirus-icon-theme \
    && ok "papirus-icon-theme installato" \
    || { warn "pacman fallito, provo AUR"; "$AUR_HELPER" -S --needed --noconfirm papirus-icon-theme; }
fi

# --- 2. papirus-folders Catppuccin (AUR) ------------------------------------
say "Installazione papirus-folders-catppuccin-git"
if pacman -Q papirus-folders-catppuccin-git >/dev/null 2>&1 || \
   pacman -Q papirus-folders >/dev/null 2>&1; then
  skip "papirus-folders già installato"
else
  "$AUR_HELPER" -S --needed --noconfirm papirus-folders-catppuccin-git 2>/dev/null \
    || "$AUR_HELPER" -S --needed --noconfirm papirus-folders 2>/dev/null \
    || warn "papirus-folders non installato — installa manualmente"
fi

# --- 3. Applica folder color Catppuccin Mocha Blue -------------------------
say "Applica folder color: catppuccin-mocha-blue"
if command -v papirus-folders >/dev/null 2>&1; then
  papirus-folders -C catppuccin-mocha-blue --theme Papirus-Dark 2>/dev/null \
    && ok "Papirus folders: catppuccin-mocha-blue (Papirus-Dark)" \
    || {
      warn "catppuccin-mocha-blue non disponibile, provo mocha-blue"
      papirus-folders -C mocha-blue --theme Papirus-Dark 2>/dev/null \
        || warn "papirus-folders color non applicato"
    }
else
  warn "papirus-folders non trovato nel PATH — esegui manualmente dopo l'installazione"
fi

# --- 4. Imposta icon theme KDE (Papirus-Dark) --------------------------------
say "Imposta icon theme KDE: Papirus-Dark"
kwriteconfig6 --file ~/.config/kdeglobals --group Icons --key Theme "Papirus-Dark" 2>/dev/null \
  && ok "Icon theme KDE: Papirus-Dark" \
  || warn "kwriteconfig6 non disponibile"

# GTK
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" 2>/dev/null \
    && ok "Icon theme GTK: Papirus-Dark" || true
fi

# gtk-3.0
GTK3_CONF="$HOME/.config/gtk-3.0/settings.ini"
if [ -f "$GTK3_CONF" ]; then
  sed -i 's/gtk-icon-theme-name=.*/gtk-icon-theme-name=Papirus-Dark/' "$GTK3_CONF" 2>/dev/null \
    && ok "gtk-3.0 icon theme aggiornato" || true
fi

# --- 5. Ricarica icone -------------------------------------------------------
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
# Notifica plasmashell aggiornamento icone
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true

ok "09-icons-papirus completa"
echo ""
echo "  Papirus-Dark con folder Catppuccin Mocha Blue attivo."
echo "  Per cambiare accent: papirus-folders -C catppuccin-mocha-mauve --theme Papirus-Dark"
echo "  Per vedere i colori disponibili: papirus-folders -l"
