#!/usr/bin/env bash
# install.sh — entrypoint per il rice Catppuccin Mocha.
# Ogni fase chiede conferma. Idempotente: rieseguibile senza rompere nulla.
#
#   bash install.sh              # interattivo (conferma per fase)
#   bash install.sh --yes        # auto-sì per tutte le fasi
#   bash install.sh --only 03    # esegue solo la fase 03
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_YES=false
ONLY=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    --only) shift; ONLY="${1:-}" ;;
    *) [ -n "$ONLY" ] && ONLY="$arg" ;;
  esac
done

# Colori
say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

confirm() {
  if $AUTO_YES; then return 0; fi
  read -p "$1 [y/N] " yn
  [[ "$yn" == [yY] ]]
}

say "============================================"
say "  Catppuccin Mocha Rice — Lenovo LOQ 17IRX10"
say "  KDE Plasma 6.7 + Hyprland"
say "============================================"
echo ""
echo "  Scegli la sezione da installare:"
echo "    [K] DE Plasma (default)"
echo "    [H] Hyprland"
echo "    [A] Tutta (KDE + Hyprland)"
echo ""
read -p "Scelta [K/H/A]: " CHOICE
CHOICE=${CHOICE:-K}
echo ""

# --- FASE 0: Prerequisiti ----------------------------------------------------
say "FASE 0: Prerequisiti (yay, stow, konsave)"
if [ -n "$ONLY" ] && [ "$ONLY" != "00" ]; then skip; else
  confirm "Eseguire check prerequisiti?" && bash "$HERE/scripts/00-prereqs.sh"
fi

# --- FASE 06: Backup konsave (PRIMA di toccare nulla) -----------------------
say "FASE 06: Backup Plasma profile (konsave)"
if [ -n "$ONLY" ] && [ "$ONLY" != "06" ]; then skip; else
  confirm "Eseguire backup konsave (CONSIGLIATO prima di procedere)?" && bash "$HERE/scripts/06-konsave-backup.sh"
fi

# --- FASE 03: Fonts ---------------------------------------------------------
say "FASE 03: Nerd Fonts + Font Awesome"
if [ -n "$ONLY" ] && [ "$ONLY" != "03" ]; then skip; else
  confirm "Installare Nerd Fonts (JetBrains Mono, Meslo, Hack)?" && bash "$HERE/scripts/03-fonts.sh"
fi

# --- FASE 02: Shell prompt (starship) ---------------------------------------
say "FASE 02: Shell (starship + zsh plugins)"
if [ -n "$ONLY" ] && [ "$ONLY" != "02" ]; then skip; else
  confirm "Installare starship e swap p10k → starship?" && bash "$HERE/scripts/02-shell.sh"
fi

# --- FASE 01: Terminale (ghostty + fastfetch) --------------------------------
say "FASE 01: Terminale (ghostty + fastfetch)"
if [ -n "$ONLY" ] && [ "$ONLY" != "01" ]; then skip; else
  confirm "Installare ghostty + fastfetch con config One Dark Pro?" && bash "$HERE/scripts/01-terminal.sh"
fi

# --- FASE 04: Tema Catppuccin Mocha ------------------------------------------
say "FASE 04: Tema Catppuccin Mocha (Plasma + Kvantum + GTK + Konsole)"
if [ -n "$ONLY" ] && [ "$ONLY" != "04" ]; then skip; else
  confirm "Applicare tema Catppuccin Mocha ovunque?" && bash "$HERE/scripts/04-theme-catppuccin.sh"
fi

# --- FASE 07: Eye-care + trasparenza (eye-care, blur, blue-light) -----------
say "FASE 07: Eye-care + trasparenza (blur KWin, kdeglobals)"
if [ -n "$ONLY" ] && [ "$ONLY" != "07" ]; then skip; else
  confirm "Applicare eye-care + trasparenza (Ghostty/Konsole/KWin)?" && bash "$HERE/scripts/07-eyecare-transparency.sh"
fi

# --- FASE 05: Plasma widgets (opzionali) ------------------------------------
say "FASE 05: Plasma widgets (opzionali — documentazione)"
if [ -n "$ONLY" ] && [ "$ONLY" != "05" ]; then skip; else
  confirm "Mostrare widget opzionali?" && bash "$HERE/scripts/05-plasma-widgets.sh"
fi

# --- FASE H: Hyprland (opzionale) -------------------------------------------
if [[ "$CHOICE" =~ ^[HhAa]$ ]]; then
    say "FASE H: Installazione Hyprland"
    bash "$HERE/../install-scripts/install-hyprland.sh"
fi

# --- Fine -------------------------------------------------------------------
echo ""
ok "============================================"
ok "  Rice Catppuccin Mocha installato!"
ok "============================================"
echo ""
if [[ "$CHOICE" =~ ^[Hh]$ ]]; then
    echo "  Hyprland installato!"
    echo "  Per avviare: Hyprland da terminale"
    echo "  Hotkeys: SUPER+Return (term), SUPER+D (menu), SUPER+Q (close)"
elif [[ "$CHOICE" =~ ^[Kk]$ ]]; then
    echo "  KDE Plasma installato!"
    echo "  Riavvia shell: exec zsh"
    echo "  Imposta wallpaper: bash $HERE/scripts/11-wallpaper-catppuccin.sh"
    echo "  Installa icone:    bash $HERE/scripts/09-icons-papirus.sh"
    echo "  Installa GTK:      bash $HERE/scripts/10-gtk-catppuccin.sh"
    echo "  Verifica visiva:   bash $HERE/scripts/verify-catppuccin.sh"
else
    echo "  Tutte le sezioni installate!"
    echo "  KDE Plasma: seleziona Plasma dal display manager"
    echo "  Hyprland: seleziona Hyprland dal display manager"
fi
echo ""
echo "  Per rollback: bash $HERE/scripts/99-rollback.sh"
echo ""
warn "  NOTA: se qualcosa non va, riavvia Plasma: kquitapp6 plasmashell && kstart plasmashell"
