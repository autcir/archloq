#!/usr/bin/env bash
# =============================================================================
# 21 — build the two-row panel from scratch
# =============================================================================
# Built with xfconf-query rather than by shipping a panel layout XML file.
#
# Reason: xfce4-panel's layout XML is version-coupled and a malformed one is
# silently ignored -- xfce4-panel falls back to a default panel and reports
# nothing. Building through the same interface the panel itself uses means a typo
# becomes a visible error here instead of a mystery on the next login.
#
# Layout
#   top     whisker-menu | window-buttons | workspace-switcher | clock | indicator
#   bottom  docklike | systray | netload | battery | cpugraph | genmon
#
# Safe to re-run: panels are removed and rebuilt, so the result is deterministic.
# =============================================================================

set -euo pipefail

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  printf 'no DISPLAY. Run this from inside the Xfce session, not over SSH.\n' >&2
  exit 1
fi
command -v xfconf-query >/dev/null 2>&1 || {
  printf 'xfconf-query not found; is xfce4-settings installed?\n' >&2
  exit 1
}
command -v xfce4-panel >/dev/null 2>&1 || {
  printf 'xfce4-panel not found\n' >&2
  exit 1
}

# Property write that reports loudly instead of failing silently.
setprop() {
  local channel="$1" prop="$2" type="$3" value="$4"
  if ! xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value" 2>/dev/null; then
    printf '  warn: could not set %s%s=%s\n' "$channel" "$prop" "$value" >&2
  fi
}

removeprop() {
  local channel="$1" prop="$2"
  xfconf-query -c "$channel" -r "$prop" 2>/dev/null || true
}

add_plugin() {
  local panel="$1" plugin="$2" id="${3:-}"
  local do_add id_out
  do_add="$(xfconf-query -c xfce4-panel -p "/panels/panel-${panel}/plugins" -l 2>/dev/null)"

  # Adding is done by writing the last-but-one item to a descriptor array; this
  # is the documented-in-source idiom for xfce4-panel 4.20.
  local count=0 prev=""
  while read -r line; do
    [[ -n "$line" ]] || continue
    count=$((count + 1))
    prev="$line"
  done <<<"$do_add"

  id_out="$(xfconf-query -c xfce4-panel -p "/panels/panel-${panel}/plugins" \
    -a -t string -n "${id:-$plugin}" 2>&1)"
  if [[ "$id_out" == *"Failed"* ]]; then
    printf '  cannot add %s to panel %s: %s\n' "$plugin" "$panel" "$id_out" >&2
    return 1
  fi
  printf '  added %-22s to panel %s\n' "$plugin" "$panel"
  unset prev count
}

printf '== building the Xfce panel ==\n'

# Remove any existing panels so the layout is deterministic across re-runs.
panel_count="$(xfconf-query -c xfce4-panel -p /panels -l 2>/dev/null | grep -c '^/panels/panel-[0-9]*/$' || true)"
if ((panel_count > 0)); then
  printf 'removing %s existing panel(s)\n' "$panel_count"
  xfconf-query -c xfce4-panel -p /panels -r -f 2>/dev/null || true
fi

xfconf-query -c xfce4-panel -p /panels -n -t int -s 2
xfconf-query -c xfce4-panel -p /panels/panel-0 -n -t string -s "top"
xfconf-query -c xfce4-panel -p /panels/panel-0/size-mode -n -t string -s "auto"
xfconf-query -c xfce4-panel -p /panels/panel-0/position -n -t string -s "p=6;x=0;y=0"

xfconf-query -c xfce4-panel -p /panels/panel-1 -n -t string -s "bottom"
xfconf-query -c xfce4-panel -p /panels/panel-1/size-mode -n -t string -s "auto"
xfconf-query -c xfce4-panel -p /panels/panel-1/position -n -t string -s "p=2;x=0;y=0"

printf 'top panel plugins:\n'
add_plugin 0 "whiskermenu"
add_plugin 0 "windowbuttons"
add_plugin 0 "pager"
add_plugin 0 "indicator"
add_plugin 0 "clock"

printf 'bottom panel plugins:\n'
add_plugin 1 "docklike"
add_plugin 1 "systray"
add_plugin 1 "netload"
add_plugin 1 "acpi"
add_plugin 1 "cpugraph"
add_plugin 1 "genmon"

# Panel preferences that matter and are not obvious from the plugin list.
setprop xfce4-panel "/panels/panel-0/length"   int  100
setprop xfce4-panel "/panels/panel-0/position-socket" int 1
setprop xfce4-panel "/panels/panel-1/length"   int  100
setprop xfce4-panel "/panels/panel-1/position-socket" int 1

# Hide the panel fullscreen-wards: it is the single most annoying default in any
# tiling-adjacent workflow, and easy to turn on by hand later.
setprop xfce4-panel "/panels/panel-0/autohide" bool false

printf '\ndone. Log out and back in if the layout does not appear immediately.\n'
printf 'troubleshooting: xfconf-query -c xfce4-panel -p /panels/panel-0/plugins -l\n'
