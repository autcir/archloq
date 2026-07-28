#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"
ID="${1:-}"
HANDOFF_ID="${2:-NO-HANDOFF}"

if [ -z "$ID" ]; then
  echo "Uso: archive-loop.sh <LOOP_ID> [HANDOFF_ID]" >&2
  exit 1
fi

SRC="$DOCS_DIR/loop/${ID}.md"
DST="$DOCS_DIR/loop/archive/${ID}.md"
[ -f "$SRC" ] || { echo "ERRORE: $SRC non trovato" >&2; exit 1; }

acquire_lock "$DOCS_DIR"

TS=$(iso_timestamp)
mkdir -p "$DOCS_DIR/loop/archive"

# --- Backup per rollback -----------------------------------------------------
BACKUP_DIR=$(mktemp -d)
cp "$SRC" "$BACKUP_DIR/src.md"
[ -f "$DOCS_DIR/ROADMAP.md" ] && cp "$DOCS_DIR/ROADMAP.md" "$BACKUP_DIR/ROADMAP.md.bak"
HIST="$DOCS_DIR/archive/HISTORY.md"
[ -f "$HIST" ] && cp "$HIST" "$BACKUP_DIR/HISTORY.md.bak"

rollback() {
  echo "✗ Verifica integrità fallita — rollback in corso..." >&2
  rm -f "$DST"
  cp "$BACKUP_DIR/src.md" "$SRC"
  [ -f "$BACKUP_DIR/ROADMAP.md.bak" ] && cp "$BACKUP_DIR/ROADMAP.md.bak" "$DOCS_DIR/ROADMAP.md"
  if [ -f "$BACKUP_DIR/HISTORY.md.bak" ]; then
    cp "$BACKUP_DIR/HISTORY.md.bak" "$HIST"
  else
    rm -f "$HIST"
  fi
  rm -rf "$BACKUP_DIR"
  echo "✓ Rollback completato. Nessuna modifica persistita. Correggi i riferimenti rotti e riprova." >&2
  release_lock
  exit 1
}

# --- 1. Scrivi il file archiviato (ma non cancellare ancora il SRC) --------
{
  echo "> COMPLETATO: ${TS}"
  echo "> Chiuso da: ${HANDOFF_ID}"
  echo "> Verifica: PASSED"
  echo ""
  cat "$SRC"
} > "$DST"

# --- 2. Aggiorna ROADMAP.md (sed portabile GNU/BSD) -------------------------
if [ -f "$DOCS_DIR/ROADMAP.md" ]; then
  portable_sed_inplace "s/| ${ID} | [A-Z]* |/| ${ID} | DONE |/" "$DOCS_DIR/ROADMAP.md"
fi

# --- 3. Log append-only in HISTORY.md ---------------------------------------
mkdir -p "$DOCS_DIR/archive"
[ -f "$HIST" ] || echo "# HISTORY.md — Log cronologico master (append-only)" > "$HIST"
# Il '|| true' finale è necessario: con `set -o pipefail` attivo, se grep non
# trova nessuna riga "## Entry N" (es. file appena creato) la pipe intera
# restituisce il suo exit code non-zero e lo script muore qui silenziosamente,
# saltando il check di integrità e il rollback che seguono.
LAST_N=$(grep -oE '^## Entry [0-9]+' "$HIST" 2>/dev/null | sed -E 's/## Entry //' | sort -n | tail -1 || true)
NEXT_N=$(( ${LAST_N:-0} + 1 ))
{
  echo ""
  echo "## Entry ${NEXT_N}"
  echo "Timestamp: ${TS}"
  echo "Azione: Archiviazione ${ID}"
  echo "Handoff: ${HANDOFF_ID}"
} >> "$HIST"

# --- 4. Verifica integrità PRIMA di cancellare il SRC e committare ---------
# check-integrity.sh ora controlla lo stato con SRC ancora presente E DST
# già scritto, così vede esattamente lo stato che risulterebbe dal commit,
# senza aver ancora reso irreversibile nulla.
if ! bash "$SCRIPT_DIR/check-integrity.sh"; then
  rollback
fi

# --- 5. Solo ora, con verifica passata, rendi permanente il cambiamento ----
rm "$SRC"
rm -rf "$BACKUP_DIR"

release_lock

echo "Archiviato: $DST"
echo "✓ ROADMAP.md aggiornato automaticamente (Status → DONE)"
echo "✓ HISTORY.md entry ${NEXT_N} aggiunta automaticamente"
echo "✓ Verifica integrità PASSED"
