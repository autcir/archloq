#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"
FAIL=0
echo "== Verifica integrità referenziale =="

# Raccogli TUTTI i file .md rilevanti: top-level, loop attivi, archivio, handoff.
# L'originale controllava solo $DOCS_DIR/*.md e handoff/*.md, perdendo i
# riferimenti rotti dentro altri loop attivi o dentro l'archivio stesso.
SEARCH_TARGETS=()
[ -d "$DOCS_DIR" ] && while IFS= read -r -d '' f; do SEARCH_TARGETS+=("$f"); done \
  < <(find "$DOCS_DIR" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
[ -d "$DOCS_DIR/loop" ] && while IFS= read -r -d '' f; do SEARCH_TARGETS+=("$f"); done \
  < <(find "$DOCS_DIR/loop" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
[ -d "$DOCS_DIR/loop/archive" ] && while IFS= read -r -d '' f; do SEARCH_TARGETS+=("$f"); done \
  < <(find "$DOCS_DIR/loop/archive" -maxdepth 1 -name "*.md" -print0 2>/dev/null)
[ -d "$DOCS_DIR/handoff" ] && while IFS= read -r -d '' f; do SEARCH_TARGETS+=("$f"); done \
  < <(find "$DOCS_DIR/handoff" -maxdepth 1 -name "*.md" -print0 2>/dev/null)

if [ ${#SEARCH_TARGETS[@]} -eq 0 ]; then
  echo "✓ Nessun documento da verificare (docs/ vuoto o assente)"
  exit 0
fi

for f in "$DOCS_DIR"/loop/archive/*.md; do
  [ -f "$f" ] || continue
  ID=$(basename "$f" .md)
  # Cerca riferimenti al path pre-archiviazione (loop/${ID}.md) che NON siano
  # già corretti (loop/archive/${ID}.md) in tutti i target raccolti sopra.
  if grep -ln "loop/${ID}\.md" "${SEARCH_TARGETS[@]}" 2>/dev/null | grep -v "loop/archive/${ID}" >/dev/null; then
    echo "✗ Riferimento a path vecchio per ${ID} in:"
    grep -ln "loop/${ID}\.md" "${SEARCH_TARGETS[@]}" 2>/dev/null | grep -v "loop/archive/${ID}" | sed 's/^/    /'
    FAIL=1
  fi
done

[ "$FAIL" -eq 0 ] && echo "✓ Nessun riferimento rotto" || { echo "✗ Correggi prima di chiudere sessione"; exit 1; }
