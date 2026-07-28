#!/usr/bin/env bash
# auto-archive-done-loops.sh — Status=DONE|CANCELLED → archive without asking Ciro.
# Tracked SoT under ebrain/ebrain-system/scripts/ (runtime/ is gitignored).
set -euo pipefail

ROOT="${EROS_ROOT:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi
export EROS_ROOT="$ROOT"

# lib + archive-loop live under runtime plugin if present, else we embed minimal
PLUGIN_BIN="${ROOT}/runtime/integrations/loop-tracker/bin"
LIB="${PLUGIN_BIN}/../scripts/lib.sh"
ARCHIVE_SH="${PLUGIN_BIN}/archive-loop.sh"

if [ ! -f "$LIB" ] || [ ! -f "$ARCHIVE_SH" ]; then
  echo "ERRORE: loop-tracker plugin missing under runtime/integrations/loop-tracker/" >&2
  echo "  Need lib.sh + archive-loop.sh (local plugin install)." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$LIB"

if [ "${EROS_AUTO_ARCHIVE:-1}" = "0" ] || [ "${EROS_AUTO_ARCHIVE:-1}" = "off" ]; then
  echo "auto-archive: disabled (EROS_AUTO_ARCHIVE=0)"
  exit 0
fi

DOCS_DIR="$(resolve_docs_dir)"
LOOP_DIR="${DOCS_DIR}/loop"
ARCHIVE_DIR="${LOOP_DIR}/archive"
mkdir -p "$LOOP_DIR" "$ARCHIVE_DIR"

HANDOFF_ID="${1:-AUTO-ARCHIVE}"
DRY="${EROS_AUTO_ARCHIVE_DRY:-0}"

_loop_is_terminal() {
  local f="$1" head
  head="$(head -n 40 "$f" 2>/dev/null || true)"
  if printf '%s\n' "$head" | grep -Eiq '\|\s*\*\*Status\*\*\s*\|\s*(DONE|CANCELLED)\s*\|'; then
    return 0
  fi
  if printf '%s\n' "$head" | grep -Eiq '^Status:\s*(DONE|CANCELLED)(\s|$|\()'; then
    return 0
  fi
  if printf '%s\n' "$head" | grep -Eiq '\|\s*Status\s*\|\s*(DONE|CANCELLED)\s*\|'; then
    return 0
  fi
  return 1
}

archived=0
skipped=0
failed=0
candidates=()

shopt -s nullglob
for f in "${LOOP_DIR}"/LOOP-*.md; do
  base="$(basename "$f" .md)"
  if _loop_is_terminal "$f"; then
    candidates+=("$base")
  else
    skipped=$((skipped + 1))
  fi
done

if [ ${#candidates[@]} -eq 0 ]; then
  echo "auto-archive: no DONE/CANCELLED loops in ${LOOP_DIR}"
  exit 0
fi

echo "auto-archive: ${#candidates[@]} candidate(s) in ${LOOP_DIR}"
for id in "${candidates[@]}"; do
  if [ "$DRY" = "1" ]; then
    echo "  DRY → would archive ${id}"
    archived=$((archived + 1))
    continue
  fi
  echo "  archiving ${id} (HANDOFF=${HANDOFF_ID})..."
  if bash "$ARCHIVE_SH" "$id" "$HANDOFF_ID"; then
    archived=$((archived + 1))
  else
    echo "  ✗ archive failed: ${id}" >&2
    failed=$((failed + 1))
  fi
done

echo "auto-archive: archived=${archived} skipped_active=${skipped} failed=${failed}"
if [ "$failed" -gt 0 ] && [ "$archived" -eq 0 ]; then
  exit 1
fi
exit 0
