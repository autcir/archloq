#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"

if [ ! -d "$DOCS_DIR/handoff" ]; then
  exit 0
fi

# Trova l'handoff più recente per timestamp nel filename (non mtime, vedi lib.sh)
LATEST=$(find "$DOCS_DIR/handoff" -maxdepth 1 -name "HANDOFF-*.md" 2>/dev/null | sort | tail -1 || true)

if [ -z "$LATEST" ]; then
  printf '{"systemMessage": "loop-tracker: sessione conclusa senza nessun handoff registrato. Considera /new-handoff prima di chiudere."}\n'
  exit 0
fi

# Se l'handoff più recente è più vecchio di 5 minuti, probabilmente la sessione
# ha fatto lavoro dopo l'ultimo handoff senza registrarlo.
LATEST_FS_TS=$(basename "$LATEST" .md | sed 's/HANDOFF-//')
LATEST_EPOCH=$(date -d "${LATEST_FS_TS:0:8} ${LATEST_FS_TS:9:2}:${LATEST_FS_TS:11:2}:${LATEST_FS_TS:13:2}" +%s 2>/dev/null \
  || date -j -f "%Y%m%dT%H%M%S" "$LATEST_FS_TS" +%s 2>/dev/null \
  || echo 0)
NOW_EPOCH=$(date +%s)

if [ "$LATEST_EPOCH" -gt 0 ] && [ $((NOW_EPOCH - LATEST_EPOCH)) -gt 300 ]; then
  printf '{"systemMessage": "loop-tracker: ultimo handoff registrato oltre 5 minuti fa. Se hai lavorato dopo, valuta /new-handoff prima di chiudere."}\n'
fi
