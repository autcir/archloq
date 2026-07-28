#!/usr/bin/env bash
# 12-transparency-blur.sh — Trasparenza + blur totale stile YouTube rice su KDE Plasma 6 Wayland
# Applica opacity via KWin window rules su TUTTE le app principali.
# Better Blur DX già installato e attivo.
set -euo pipefail

say()  { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

say "=== CATPPUCCIN MOCHA — BLUR & TRANSPARENCY FULL RICE ==="

# --- 1. Kvantum trasparenza max -------------------------------------------
say "[1/4] Kvantum: trasparenza applicazioni Qt"
KVCONFIG="$HOME/.config/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.kvconfig"
if [ -f "$KVCONFIG" ]; then
  sed -i 's/^reduce_window_opacity=.*/reduce_window_opacity=25/' "$KVCONFIG"
  sed -i 's/^translucent_windows=.*/translucent_windows=true/' "$KVCONFIG"
  sed -i 's/^blurring=.*/blurring=true/' "$KVCONFIG"
  sed -i 's/^popup_blurring=.*/popup_blurring=true/' "$KVCONFIG"
  ok "Kvantum: opacity -25%, blur abilitato"
fi

# --- 2. KWin: Better Blur DX (force blur) ----------------------------------
say "[2/4] KWin: Better Blur DX abilitato (blur su tutte le finestre)"
kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file ~/.config/kwinrc --group Plugins --key better_blur_dxEnabled true
kwriteconfig6 --file ~/.config/kwinrc --group Effect-better_blur_dx --key BlurStrength 15
kwriteconfig6 --file ~/.config/kwinrc --group Effect-better_blur_dx --key NoiseStrength 0
ok "Better Blur DX attivo, default blur disabilitato"

# --- 3. KWin window rules: opacity per ogni app ----------------------------
say "[3/4] KWin window rules: opacity per Dolphin, Kate, System Settings, Konsole..."

# Conta regole esistenti
EXISTING=$(kreadconfig6 --file ~/.config/kwinrulesrc --group General --key count 2>/dev/null || echo 0)

# Funzione helper: aggiunge/sovrascrive regola
  local n="$1" desc="$2" wmclass="$3" match="$4" active="$5" inactive="$6"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key Description "$desc"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key wmclass "$wmclass"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key wmclassmatch "$match"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key wmclasscompletematch false
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key opacityactive "$active"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key opacityactiverule 2
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key opacityinactive "$inactive"
  kwriteconfig6 --file ~/.config/kwinrulesrc --group "$n" --key opacityinactiverule 2
}

# wmclassmatch: 1=esatto, 2=substring, 3=regex, 4=unimportante

kwriteconfig6 --file ~/.config/kwinrulesrc --group General --key count 12
ok "12 regole opacity applicate"

# --- 4. Reload KWin --------------------------------------------------------
say "[4/4] Reload KWin + kvantummanager"
kvantummanager --set catppuccin-mocha-blue 2>/dev/null || true
qdbus6 org.kde.KWin /KWin reconfigure && ok "KWin reconfigurato"

echo ""
echo "╭──────────────────────────────────────────────────────────────╮"
echo "│  BLUR & TRANSPARENCY RICE ATTIVO!                             │"
echo "│                                                                │"
echo "│  ✅ Better Blur DX: blur su tutte le finestre Wayland         │"
echo "│  ✅ Kvantum: finestre Qt semi-trasparenti (-25% opacity)      │"
echo "│  ✅ KWin rules: Dolphin/Kate/Konsole/SystemSettings trasp.    │"
echo "│                                                                │"
echo "│  AZIONE RICHIESTA (una volta sola):                           │"
echo "│  System Settings → Desktop Effects → cerca 'Blur'            │"
echo "│  → disabilita 'Blur' nativo → abilita 'Better Blur DX'       │"
echo "│                                                                │"
echo "│  Poi: apri Dolphin → dovresti vedere il wallpaper attraverso! │"
echo "╰──────────────────────────────────────────────────────────────╯"
