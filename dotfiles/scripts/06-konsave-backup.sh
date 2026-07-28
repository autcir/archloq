#!/usr/bin/env bash
# 06-konsave-backup.sh — backup dello stato attuale di Plasma PRIMA di toccare nulla.
# SEMPRE ESEGUIRE PRIMA degli script 01-05. Idempotente: non sovrascrive backup esistenti.
set -euo pipefail

say()  { printf '\n\033[1;36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
skip() { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }

BACKUP_NAME="loq-pre-onedark-$(date +%Y%m%dT%H%M%S)"

say "Checking konsave"
if ! command -v konsave >/dev/null 2>&1; then
  echo "[ERR] konsave non installato. Esegui prima 00-prereqs.sh" >&2
  exit 1
fi

say "Creating Plasma profile backup: $BACKUP_NAME"
if konsave -l 2>/dev/null | grep -q "$BACKUP_NAME"; then
  skip "backup $BACKUP_NAME già esistente"
else
  konsave -s "$BACKUP_NAME"
  ok "backup creato: $BACKUP_NAME"
fi

say "Exporting backup to ~/loq-konsave-backups/"
mkdir -p "$HOME/loq-konsave-backups"
konsave -e "$BACKUP_NAME" -d "$HOME/loq-konsave-backups" 2>/dev/null || true
ok "export completato"

echo ""
echo "  Per ripristinare: bash $(dirname "$0")/99-rollback.sh $BACKUP_NAME"
ok "06-konsave-backup completa"
