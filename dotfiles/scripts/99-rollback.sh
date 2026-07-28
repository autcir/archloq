#!/usr/bin/env bash
# 99-rollback.sh — ripristina lo stato pre-One Dark Pro da backup konsave.
# Uso: bash 99-rollback.sh [BACKUP_NAME]
# Senza argomenti lista i backup disponibili.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
err()  { printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; }

if ! command -v konsave >/dev/null 2>&1; then
  err "konsave non installato"
  exit 1
fi

BACKUP_NAME="${1:-}"

if [ -z "$BACKUP_NAME" ]; then
  say "Backup konsave disponibili:"
  konsave -l 2>/dev/null || echo "  (nessun backup trovato)"
  echo ""
  echo "  Uso: bash 99-rollback.sh <BACKUP_NAME>"
  exit 0
fi

say "Ripristinando backup: $BACKUP_NAME"
read -p "Procedere con il rollback? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
  echo "Rollback annullato."
  exit 0
fi

konsave -a "$BACKUP_NAME"
ok "Rollback completato. Riavvia Plasma: systembar kquitapp6 plasmashell && kstart plasmashell"
