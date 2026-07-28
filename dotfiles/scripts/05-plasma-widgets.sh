#!/usr/bin/env bash
# 05-plasma-widgets.sh — plasmoid/widget opzionali per il rice.
# NON bloccante: se fallisce, il rice è comunque funzionale.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

# Widget opzionali (documentati, non installati automaticamente)
say "Plasma widgets opzionali (documentati, non auto-installati):"
echo "  - Panon (audio visualizer):       https://store.kde.org/p/1317704/"
echo "  - Redshift Control:                https://store.kde.org/p/994453/"
echo "  - Plasma Calculator (inline):      https://store.kde.org/p/1160684/"
echo "  - Active Blur (compositor effect): https://store.kde.org/p/1317704/"
echo ""
echo "  Per installare: Scarica .plasmoid → plasma-pkg -i file.plasmoid"
echo "  Oppure: System Settings → Plasma Shell → Get New Widgets"

ok "05-plasma-widgets completa (nessuna azione richiesta)"
