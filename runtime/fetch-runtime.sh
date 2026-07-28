#!/usr/bin/env bash
# fetch-runtime.sh — Clone the upstream reference repositories into runtime/.
#
# These are third-party sources kept for reference and for building the local
# LLM stack. They are deliberately NOT tracked by archloq: vendoring them would
# add ~9,800 files, and tracking them as submodules previously left every fresh
# clone with nine empty directories.
#
# Safe to re-run: existing clones are updated, not re-cloned.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

say() { printf '\n\033[1;35m[INFO]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[OK]\033[0m  %s\n' "$*"; }
err() { printf '\033[1;31m[ERR]\033[0m %s\n' "$*" >&2; }

# name|url|depth  — depth 1 for the large inference repos; full history is not
# needed to build or read them.
REPOS=(
  "LenovoLegionLinux|https://github.com/johnfanv2/LenovoLegionLinux.git|0"
  "loq-control|https://github.com/0J33/loq-control.git|0"
  "legion-linux-toolkit|https://github.com/VVAT3R/legion-linux-toolkit.git|0"
  "intel-undervolt|https://github.com/kitsunyan/intel-undervolt.git|0"
  "intel-pstate-states|https://github.com/gghh/intel-pstate-states.git|0"
  "ollama|https://github.com/ollama/ollama.git|1"
  "llama.cpp|https://github.com/ggml-org/llama.cpp.git|1"
  "open-webui|https://github.com/open-webui/open-webui.git|1"
)

ONLY="${1:-}"
[ -n "$ONLY" ] && say "Fetching only: $ONLY"

failed=()

for entry in "${REPOS[@]}"; do
  IFS='|' read -r name url depth <<< "$entry"
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue

  if [ -d "$name/.git" ]; then
    say "Updating $name"
    if git -C "$name" pull --ff-only --quiet; then
      ok "$name updated"
    else
      err "$name: pull failed (local changes?) — skipped"
      failed+=("$name")
    fi
    continue
  fi

  if [ -e "$name" ] && [ ! -d "$name/.git" ]; then
    err "$name exists but is not a git clone — leaving it alone"
    failed+=("$name")
    continue
  fi

  say "Cloning $name"
  args=(--quiet)
  [ "$depth" = "1" ] && args+=(--depth 1)
  if git clone "${args[@]}" "$url" "$name"; then
    ok "$name cloned"
  else
    err "$name: clone failed"
    failed+=("$name")
  fi
done

# rtx5060-setup is a local reference document, not an upstream clone.
if [ ! -f rtx5060-setup/README.md ]; then
  err "rtx5060-setup/README.md missing — it ships with archloq, not upstream"
fi

echo
if [ ${#failed[@]} -eq 0 ]; then
  ok "All reference repositories ready."
else
  err "Completed with ${#failed[@]} failure(s): ${failed[*]}"
  exit 1
fi
