#!/usr/bin/env bash
# new-loop.sh — LOOP grado banca (SOTA July 2026)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

DOCS_DIR="$(resolve_docs_dir)"
FEATURE="${1:-}"
DESC="${2:-}"

if [ -z "$FEATURE" ]; then
  echo "Uso: new-loop.sh <FEATURE> [descrizione]" >&2
  exit 1
fi
if ! [[ "$FEATURE" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "ERRORE: FEATURE deve contenere solo lettere, numeri, - e _ (ricevuto: '$FEATURE')" >&2
  exit 1
fi

mkdir -p "$DOCS_DIR/loop" "$DOCS_DIR/catalog/loops"
acquire_lock "$DOCS_DIR"

NEXT_NUM=$(find "$DOCS_DIR/loop" -maxdepth 1 -name "LOOP-${FEATURE}-*.md" 2>/dev/null \
  | sed -E "s/.*-([0-9]{3})\.md/\1/" | sort -n | tail -1 || true)
NEXT_NUM=$(printf "%03d" $((10#${NEXT_NUM:-0} + 1)))
ID="LOOP-${FEATURE}-${NEXT_NUM}"
TS=$(iso_timestamp)
UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CATALOG_DAY=$(date -u +"%Y-%m-%d")

OUT="$DOCS_DIR/loop/${ID}.md"

cat > "$OUT" <<EOF
# ${ID}

> **Standard SOTA July 2026 — loop = movimento in banca.**  
> Sezioni vuote vietate: contenuto o \`N/A — motivo\`.  
> Chiusura solo con VERIFICA pass + proof level dichiarato.

---

## Front matter

| Campo | Valore |
|-------|--------|
| **ID** | ${ID} |
| **Status** | PLANNED |
| **Created** | ${TS} |
| **Created UTC** | ${UTC} |
| **Updated** | ${TS} |
| **Feature** | ${FEATURE} |
| **Owner** | **COMPILARE** (agent/team/human) |
| **Proof required to close** | L1 min (path/test) — alza se money/outward |
| **Money/outward** | no \| observe \| gated — **COMPILARE** |
| **Auto-archive** | **YES** — set Status=DONE → tick brain-loop/loop-cycle archivia da solo (MAI chiedere a Ciro/EROS) |
| **Referenced by** | ROADMAP.md#${FEATURE} |
| **Catalog day** | ${CATALOG_DAY} |
| **SoT root** | \`${DOCS_DIR}\` |

---

## Effort

| Dimensione | Stima |
|------------|--------|
| Tempo | **COMPILARE** (es. 2h / 1d) |
| Rischio | L1–L4 — **COMPILARE** |
| Dipendenze esterne | **COMPILARE o N/A** |

---

## Dependencies

- **COMPILARE** (loop IDs, servizi, auth) o \`N/A — none\`

---

## SOURCE (stato prima)

**COMPILARE** — cosa c'è oggi, path, gap noti.

---

## TARGET (stato dopo, verificabile)

**COMPILARE** — cosa deve esistere a DONE (file, test, behaviour).

---

## BEHAVIOR atteso

${DESC:-**COMPILARE** — comportamento osservabile end-to-end.}

---

## CONSTRAINTS / VINCOLI

- Scope geo holding: Salerno + BCN se applicabile
- Money/outward: mai auto senza gate
- No legacy path non autorizzati
- Team OS: tools_allow / rag_scope rispettati
- **COMPILARE** vincoli extra o \`N/A\`

---

## VERIFICA (criteri di chiusura — obbligatori)

| # | Check | Comando/path | Pass? |
|---|--------|--------------|-------|
| 1 | TARGET raggiunto | **COMPILARE** | |
| 2 | Test o smoke | **COMPILARE** | |
| 3 | Gap espliciti in handoff se residuali | handoff id | |

---

## Evidence log (append during work)

| Timestamp | Evento | Proof |
|-----------|--------|-------|
| ${TS} | created | loop-tracker new-loop.sh |

---

## Close record (solo a DONE)

| Campo | Valore |
|-------|--------|
| Closed at | |
| Handoff ID | AUTO-ARCHIVE (se tick automatico) |
| Proof level achieved | |
| Residual gaps | |

### AUTO-ARCHIVE (obbligatorio — non chiedere a Ciro)

Quando **tutti** i check VERIFICA sono PASS e Status → **DONE** (o CANCELLED):

1. Imposta \`| **Status** | DONE |\` in questo file.
2. **STOP.** Non chiedere a Ciro, a EROS, o all'operatore di "archiviare".
3. \`auto-archive-done-loops.sh\` (brain-loop / loop-cycle timer) archivia da solo entro il prossimo tick.

Vietato: lasciare loop DONE in \`loop/\` in attesa di GO umano.

---

*Template: ebrain/brain/prompt-templates/loop/LOOP_SOTA_2026-07.md*
EOF

# ROADMAP feature table
ROADMAP="$DOCS_DIR/ROADMAP.md"
touch "$ROADMAP"
MARK_START="<!-- FEATURE:${FEATURE} START -->"
MARK_END="<!-- FEATURE:${FEATURE} END -->"

if ! grep -qF "$MARK_START" "$ROADMAP" 2>/dev/null; then
  {
    echo ""
    echo "## ${FEATURE}"
    echo "$MARK_START"
    echo "| LOOP ID | Status | Created | UTC |"
    echo "|---|---|---|---|"
    echo "$MARK_END"
  } >> "$ROADMAP"
fi

TMP=$(mktemp)
awk -v mark="$MARK_END" -v row="| ${ID} | PLANNED | ${TS} | ${UTC} |" '
  $0 == mark { print row }
  { print }
' "$ROADMAP" > "$TMP" && mv "$TMP" "$ROADMAP"

# Catalogs
mkdir -p "$DOCS_DIR/catalog" "$DOCS_DIR/catalog/loops"
DAY_CAT="$DOCS_DIR/catalog/${CATALOG_DAY}.md"
[ -f "$DAY_CAT" ] || echo "# Catalog — ${CATALOG_DAY}" > "$DAY_CAT"
echo "- \`${UTC}\` — loop created ${ID}: ${DESC:-no-desc}" >> "$DAY_CAT"

LDAY="$DOCS_DIR/catalog/loops/${CATALOG_DAY}.md"
if [ ! -f "$LDAY" ]; then
  echo "# Loops — ${CATALOG_DAY}" > "$LDAY"
  echo "" >> "$LDAY"
  echo "| UTC | ID | Feature | Status | Summary |" >> "$LDAY"
  echo "|---|---|---|---|---|" >> "$LDAY"
fi
echo "| ${UTC} | [${ID}](../../loop/${ID}.md) | ${FEATURE} | PLANNED | ${DESC:-} |" >> "$LDAY"

release_lock

echo "Creato: $OUT"
echo "✓ ROADMAP.md + catalog/${CATALOG_DAY}.md + catalog/loops/${CATALOG_DAY}.md"
echo "✓ Template grado banca — compila COMPILARE prima di lavorare / chiudere"
echo "${ID}"
