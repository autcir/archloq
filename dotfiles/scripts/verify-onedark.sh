#!/usr/bin/env bash
# verify-onedark.sh — verifica visiva coerenza tema One Dark Pro.
# Apre in sequenza: Dolphin, System Settings, Konsole (OneDark profile), e Firefox.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }

say "Verifica visiva One Dark Pro — apertura app in sequenza"

echo ""
echo "  [1/4] Dolphin (file manager Qt)"
nohup dolphin >/dev/null 2>&1 &
sleep 2

echo "  [2/4] System Settings (Qt)"
nohup systemsettings >/dev/null 2>&1 &
sleep 2

echo "  [3/4] Konsole (OneDarkPro profile)"
nohup konsole --profile OneDarkPro >/dev/null 2>&1 &
sleep 2

echo "  [4/4] Firefox (GTK)"
nohup firefox >/dev/null 2>&1 &
sleep 2

echo ""
say "App aperte. Verifica a colpo d'occhio:"
echo "  ✓ Sfondo: #282c34 (grigio scuro) ovunque"
echo "  ✓ Accent: #61afef (blu) in bottoni, highlights, selezioni"
echo "  ✓ Foreground: #abb2bf (grigio chiaro) per testo"
echo "  ✓ Nerd Font glyphs visibili in Konsole"
echo ""
echo "  Se qualcosa non è coerente, controlla:"
echo "    - System Settings → Appearance → Color → OneDarkPro"
echo "    - System Settings → Appearance → Application Style → Kvantum → OneDarkPro"
echo "    - System Settings → Appearance → GTK Style → OneDark-Pro"
echo ""
ok "Verifica avviata. Chiudi le app quando hai finito."
