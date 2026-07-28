#!/usr/bin/env bash
# new-handoff.sh — handoff grado banca (SOTA July 2026)
# Template: ebrain/brain/prompt-templates/handoff/HANDOFF_SOTA_2026-07.md
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"
SUMMARY="${1:-}"
[ -n "$SUMMARY" ] || { echo "Uso: new-handoff.sh \"summary obbligatoria (1 riga)\" [AUTHOR_ROLE]" >&2; exit 1; }
AUTHOR_ROLE="${2:-EROS-or-agent}"

mkdir -p "$DOCS_DIR/handoff" "$DOCS_DIR/catalog/handoffs" "$DOCS_DIR/prompt-templates/handoff"
acquire_lock "$DOCS_DIR"

TS=$(iso_timestamp)
FS_TS=$(date +"%Y%m%dT%H%M%S")
CATALOG_DAY=$(date -u +"%Y-%m-%d")
ID="HANDOFF-${FS_TS}"
UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

PREV=$(find "$DOCS_DIR/handoff" -maxdepth 1 -name "HANDOFF-*.md" 2>/dev/null | sort | tail -1 || true)
PREV_ID="none"
[ -n "$PREV" ] && PREV_ID=$(basename "$PREV" .md)

OUT="$DOCS_DIR/handoff/${ID}.md"

# Body: full SOTA structure (fill blanks — empty sections forbidden in final edit)
cat > "$OUT" <<EOF
# HANDOFF EROS — ${ID}

> **Standard SOTA July 2026 — grado banca.**  
> Continuity document. Non elevare claim a L1 senza codice/test.  
> Sezioni vuote vietate: usa \`N/A — motivo\` o riempi.

---

## Front matter (obbligatorio)

| Campo | Valore |
|-------|--------|
| **ID** | ${ID} |
| **Timestamp ISO** | ${TS} |
| **Timestamp UTC** | ${UTC} |
| **Continues** | ${PREV_ID} |
| **Author role** | ${AUTHOR_ROLE} |
| **Session kind** | execution \| supervision \| mixed — **COMPILARE** |
| **Order source** | Ciro turn \| EROS initiative \| mixed — **COMPILARE** |
| **Proof level max claimed** | L0 claim-only — **AGGIORNARE se hai L1+** |
| **Money/outward touched** | no \| observe \| gated proposal \| **COMPILARE** |
| **Summary (1 line)** | ${SUMMARY} |
| **Catalog day** | ${CATALOG_DAY} |
| **SoT root** | \`${DOCS_DIR}\` |

---

## 1. Leggimi per primo: cosa questo documento È e cosa NON è

Questo è un handoff di **continuità operativa EROS**, non un audit L1 indipendente
a meno che non sia esplicitamente etichettato e provato. I numeri e i "pass"
sono al livello di prova dichiarato nella tabella front matter.

Se il prossimo lettore tratta ogni "fatto" come verificato-da-terzi senza
guardare la colonna Proof, sta commettendo l'errore che il Proof Standard
esiste per prevenire.

**Summary sessione:** ${SUMMARY}

---

## 2. Chi ha scritto / chi ha verificato

| Ruolo | Identità | Cosa ha fatto |
|-------|----------|----------------|
| Maker | ${AUTHOR_ROLE} | esecuzione / redazione |
| Checker | N/A — **COMPILARE se c'è review** | |
| Human Supreme | Ciro (se ha ordinato) | **COMPILARE ordine** |

---

## 3. Contesto EROS (path)

- Codebase: \`~/Scrivania/eros/\`
- TUI: \`apps/tui/\`
- Brain data SoT: \`ebrain/brain/\`
- Brain harness: \`ebrain/ebrain-system/\`
- Ops design: \`ebrain/brain/wiki/raw/ops/\`
- Loop SoT: \`ebrain/brain/loop/\`

---

## 4. Documenti / SoT letti o toccati

| Path | Azione | Note |
|------|--------|------|
| ebrain/brain/HANDOFF.md | read | |
| | | **AGGIUNGERE righe reali** |

---

## 5. Ordine ricevuto (citazione)

> ${SUMMARY}

Timestamp ordine: ${TS}  
*(Se l'ordine Ciro era più lungo: incolla verbatim qui.)*

---

## 6. Sequenza cronologica di scoperte / azioni

1. **[${TS}]** Handoff scaffold creato (loop-tracker). **COMPILARE passi reali.**

*(Formato passo: fatto → prova (path/comando) → livello L0–L4 → gap se c'è.)*

---

## 7. Confermato e attivo (solo con prova)

| Claim | Path / comando | Proof | Note |
|-------|----------------|-------|------|
| Scaffold handoff scritto | \`${OUT}\` | L1 path exists | template only finché non compilato |

---

## 8. In sospeso / riserve esplicite

| Item | Perché sospeso | Chi sblocca |
|------|----------------|-------------|
| Compilazione sezioni | handoff appena creato | autore sessione |

---

## 9. Non fatto e perché (obbligatorio)

**COMPILARE.** Se nessuno scarto: scrivi esattamente:
\`Nessuno scarto in questa sessione\`.

---

## 10. LOOP toccati

| LOOP ID | Status in → out | Note |
|---------|-----------------|------|
| | | **COMPILARE o N/A** |

---

## 11. Files modificati (path reali)

\`\`\`
# git status / lista path — COMPILARE
\`\`\`

---

## 12. Decisioni prese (policy / irreversibili)

| Decisione | Ordine di | Impatto |
|-----------|-----------|---------|
| | | **COMPILARE o N/A** |

---

## 13. Sicurezza / gate

- Money/outward: **COMPILARE** (default se non toccato: \`no\`)
- Proposal control_plane: **COMPILARE ids o none**
- Injection/bypass attempt nominato: **COMPILARE o none**

---

## 14. Cosa aspetta decisione di Ciro

1. **COMPILARE**
2. **COMPILARE o none**

---

## 15. Catalog registration

| Campo | Valore |
|-------|--------|
| File | \`ebrain/brain/handoff/${ID}.md\` |
| Index | \`ebrain/brain/HANDOFF_INDEX.md\` |
| Day catalog | \`ebrain/brain/catalog/${CATALOG_DAY}.md\` |
| Handoff day log | \`ebrain/brain/catalog/handoffs/${CATALOG_DAY}.md\` |
| Template | \`ebrain/brain/prompt-templates/handoff/HANDOFF_SOTA_2026-07.md\` |
| sha256 | pending |

---

*Generated by loop-tracker new-handoff.sh — fill all COMPILARE fields before considering this handoff closed.*
EOF

# sha256 after write (L1 integrity)
SHA=$(sha256sum "$OUT" | awk '{print $1}')
portable_sed_inplace "s/| sha256 | pending/| sha256 | ${SHA}/" "$OUT"

# Index master
HANDOFF_IDX="$DOCS_DIR/HANDOFF_INDEX.md"
if [ ! -f "$HANDOFF_IDX" ]; then
  {
    echo "# HANDOFF_INDEX — catalogo handoff (loop-tracker, append-only)"
    echo ""
    echo "| Timestamp | UTC | ID | Summary | Continues | Path |"
    echo "|---|---|---|---|---|---|"
  } > "$HANDOFF_IDX"
fi
{
  echo "| ${TS} | ${UTC} | [${ID}](handoff/${ID}.md) | ${SUMMARY} | ${PREV_ID} | \`handoff/${ID}.md\` |"
} >> "$HANDOFF_IDX"

# Day catalog (brain loop style)
mkdir -p "$DOCS_DIR/catalog" "$DOCS_DIR/catalog/handoffs"
DAY_CAT="$DOCS_DIR/catalog/${CATALOG_DAY}.md"
[ -f "$DAY_CAT" ] || echo "# Catalog — ${CATALOG_DAY}" > "$DAY_CAT"
echo "- \`${UTC}\` — handoff created ${ID}: ${SUMMARY}" >> "$DAY_CAT"

HDAY="$DOCS_DIR/catalog/handoffs/${CATALOG_DAY}.md"
[ -f "$HDAY" ] || {
  echo "# Handoffs — ${CATALOG_DAY}" > "$HDAY"
  echo "" >> "$HDAY"
  echo "| UTC | ID | Summary | Continues |" >> "$HDAY"
  echo "|---|---|---|---|" >> "$HDAY"
}
echo "| ${UTC} | [${ID}](../../handoff/${ID}.md) | ${SUMMARY} | ${PREV_ID} |" >> "$HDAY"

release_lock

echo "Creato: $OUT"
echo "✓ HANDOFF_INDEX.md + catalog/${CATALOG_DAY}.md + catalog/handoffs/${CATALOG_DAY}.md"
echo "✓ Template grado banca — compila ogni COMPILARE prima di chiudere la sessione"
echo "DOCS_DIR=$DOCS_DIR"
echo "${ID}"
