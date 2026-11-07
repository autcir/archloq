#!/usr/bin/env bash
# =============================================================================
# 23 — load the xfconf per-channel files
# =============================================================================
# dotfiles/config/xfce/xfce-perchannel-xml/ is the versioned source of truth for
# xfconf state. xfconf rewrites those files in place whenever a setting changes
# in a GUI, so install.sh copies the tree rather than symlinking it; this script
# is what pushes the copy into the running session.
#
# xfconf has no "import" verb, so each property is written individually. Doing it
# this way means a typo produces a visible error here rather than a channel that
# silently half-applies.
# =============================================================================

set -euo pipefail

CHANNEL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config/xfce/xfce-perchannel-xml" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LIVE_ROOT="$CONFIG_HOME/xfce/xfce-perchannel-xml"

if [[ -z "${DISPLAY:-}" ]]; then
  printf 'no DISPLAY. Cannot write xfconf properties.\n' >&2
  exit 1
fi
command -v xfconf-query >/dev/null 2>&1 || {
  printf 'xfconf-query not found; is xfce4-settings installed?\n' >&2
  exit 1
}

[[ -d "$CHANNEL_ROOT" ]] || { printf 'no channel tree at %s\n' "$CHANNEL_ROOT" >&2; exit 1; }

applied=0
failed=0

# Walk one channel file: for each <property type="empty"> with children, set each
# child on the live channel. Nested empties recurse.
apply_props() {
  local channel="$1" file="$2"
  python3 - "$channel" "$file" <<'PY'
import subprocess, sys, xml.etree.ElementTree as ET

channel, path = sys.argv[1], sys.argv[2]
try:
    tree = ET.parse(path)
except ET.ParseError as exc:
    print(f"  parse error {path}: {exc}")
    sys.exit(1)

def setprop(full, node):
    kind = node.get("type")
    val = node.get("value")
    if kind is None or val is None:
        return
    ptype = {"string": "string", "int": "int", "bool": "bool",
             "double": "double", "uint": "uint", "color": "array"}.get(kind)
    if ptype is None:
        return
    args = ["xfconf-query", "-c", channel, "-p", full, "-s", "-t", ptype, "-n", val]
    r = subprocess.run(args, capture_output=True)
    print(("  ok   " if r.returncode == 0 else "  FAIL ") + full)

def walk(parent_path, elem):
    for child in elem:
        name = child.get("name")
        if not name:
            continue
        full = f"{parent_path}/{name}"
        if child.get("type") == "empty":
            walk(full, child)
        else:
            setprop(full, child)

root = tree.getroot()
walk("", root)
PY
}

for channel_dir in "$CHANNEL_ROOT"/*/; do
  channel="$(basename "$channel_dir")"
  printf '== channel %s ==\n' "$channel"
  for file in "$channel_dir"*.xml; do
    [[ -f "$file" ]] || continue
    # Ensure the channel exists before writing to it.
    xfconf-query -c "$channel" >/dev/null 2>&1 || xfconf-query -c "$channel" -n -t string -s /dev/null 2>/dev/null || true
    apply_props "$channel" "$file"
    applied=$((applied + 1))
  done
done

printf '\napplied %s channel file(s).\n' "$applied"
printf 'verify with: xfconf-query -c xfwm4 -l\n'
printf 'reference copies remain in %s\n' "$CHANNEL_ROOT"
printf 'live state (rewritten by XFCE itself) is in %s\n' "$LIVE_ROOT"
