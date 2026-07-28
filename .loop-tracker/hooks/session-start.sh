#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"

# DOCS_DIR = ebrain/brain (canon). Se assente: plugin installato ma repo non EROS.
if [ ! -d "$DOCS_DIR" ]; then
  cat <<EOF
{"systemMessage": "loop-tracker: nessun SoT ebrain/brain (o DOCS_DIR) trovato. Verrà creato al primo /new-loop. Canon: ebrain/brain/loop/."}
EOF
  exit 0
fi

OPEN_LOOPS=0
if [ -d "$DOCS_DIR/loop" ]; then
  OPEN_LOOPS=$(find "$DOCS_DIR/loop" -maxdepth 1 -name "LOOP-*.md" 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$OPEN_LOOPS" -gt 0 ]; then
  # tr traduce carattere-per-carattere: con un set di destinazione multi-char
  # come ', ' tronca al primo carattere, producendo virgole senza spazio e
  # senza modo affidabile di stripparne una finale. paste con -s -d è la via
  # portabile per unire righe con un separatore letterale.
  NAMES=$(find "$DOCS_DIR/loop" -maxdepth 1 -name "LOOP-*.md" 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | paste -sd ',' - | sed 's/,/, /g')
  MSG="loop-tracker [ebrain/brain]: ${OPEN_LOOPS} loop aperti (${NAMES}). /archive-loop o /new-handoff. SoT=${DOCS_DIR}"
else
  MSG="loop-tracker [ebrain/brain]: nessun loop aperto. SoT=${DOCS_DIR}"
fi
# Escape minimale per JSON (il messaggio non contiene virgolette per costruzione,
# ma restiamo difensivi)
MSG_ESCAPED=$(printf '%s' "$MSG" | sed 's/"/\\"/g')
printf '{"systemMessage": "%s"}\n' "$MSG_ESCAPED"
