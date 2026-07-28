#!/usr/bin/env bash
# lib.sh — funzioni condivise per gli script loop-tracker.
# Sorgente questo file, non eseguirlo direttamente.

# --- Path resolution -------------------------------------------------------
# Canon EROS (2026-07-10): dati loop/handoff/ROADMAP vivono in ebrain/brain/
# (stesso SoT del brain). ebrain-system = harness; docs/ = thin index + symlink.
#
# Priorità:
#   1) DOCS_DIR esplicito (env)
#   2) EROS_DOCS_ROOT (env o da ebrain-system/config.env)
#   3) <project>/ebrain/brain se esiste
#   4) legacy: CLAUDE_PROJECT_DIR/docs o ./docs
resolve_docs_dir() {
  if [ -n "${DOCS_DIR:-}" ]; then
    printf '%s\n' "$DOCS_DIR"
    return 0
  fi
  if [ -n "${EROS_DOCS_ROOT:-}" ]; then
    _expand_home "${EROS_DOCS_ROOT}"
    return 0
  fi

  local project=""
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    project="${CLAUDE_PROJECT_DIR}"
  elif [ -d "$(pwd)/ebrain/brain" ]; then
    project="$(pwd)"
  elif [ -d "$(pwd)/.git" ]; then
    project="$(pwd)"
  fi

  # Load ebrain-system/config.env if present (sets EROS_DOCS_ROOT)
  if [ -n "$project" ] && [ -f "${project}/ebrain/ebrain-system/config.env" ]; then
    # shellcheck disable=SC1090
    set +u
    # Extract only EROS_DOCS_ROOT / EROS_BRAIN_REPO without full bash array issues
    local line val
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        EROS_DOCS_ROOT=*)
          val="${line#EROS_DOCS_ROOT=}"
          val="${val%\"}"
          val="${val#\"}"
          val="${val%\'}"
          val="${val#\'}"
          if [ -n "$val" ]; then
            _expand_home "$val"
            return 0
          fi
          ;;
      esac
    done < "${project}/ebrain/ebrain-system/config.env"
    set -u
  fi

  if [ -n "$project" ] && [ -d "${project}/ebrain/brain" ]; then
    printf '%s\n' "${project}/ebrain/brain"
    return 0
  fi

  # Legacy fallback
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s\n' "${CLAUDE_PROJECT_DIR}/docs"
  else
    printf '%s\n' "docs"
  fi
}

_expand_home() {
  local p="$1"
  p="${p//\$\{HOME\}/$HOME}"
  p="${p/#\~/$HOME}"
  printf '%s\n' "$p"
}

# --- sed portabile (GNU vs BSD/macOS) --------------------------------------
portable_sed_inplace() {
  local expr="$1" file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

# --- File locking ------------------------------------------------------------
LOCK_FD=200
LOCK_FILE=""
LOCK_DIR=""

acquire_lock() {
  local docs_dir="$1"
  local timeout="${2:-15}"
  mkdir -p "$docs_dir/.locks"

  if command -v flock >/dev/null 2>&1; then
    LOCK_FILE="$docs_dir/.locks/loop-tracker.lock"
    eval "exec ${LOCK_FD}>\"$LOCK_FILE\""
    if ! flock -w "$timeout" "$LOCK_FD"; then
      echo "ERRORE: impossibile acquisire il lock entro ${timeout}s (${LOCK_FILE})" >&2
      echo "Un altro processo loop-tracker è già in esecuzione." >&2
      exit 1
    fi
  else
    LOCK_DIR="$docs_dir/.locks/loop-tracker.lockdir"
    local waited=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
      if [ "$waited" -ge "$timeout" ]; then
        echo "ERRORE: impossibile acquisire il lock entro ${timeout}s (${LOCK_DIR})" >&2
        echo "Un altro processo loop-tracker è già in esecuzione, o un lock è rimasto orfano." >&2
        echo "Se sei sicuro che nessun processo sia attivo: rmdir '$LOCK_DIR'" >&2
        exit 1
      fi
      sleep 1
      waited=$((waited + 1))
    done
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
  fi
}

release_lock() {
  if [ -n "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    LOCK_DIR=""
  fi
}

# --- Timestamp ISO 8601 con offset, portabile -------------------------------
iso_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%:z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z"
}
