#!/usr/bin/env bash
# =============================================================================
# 11 — desktop wallpaper
# =============================================================================
# Sets the Xfce backdrop through xfconf, which is what xfdesktop reads.
# The previous version called plasma-apply-wallpaperimage, a Plasma 6 tool.
#
# xfdesktop keys backdrops by workspace, so this has to be written per workspace.
# =============================================================================

set -euo pipefail

WALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../wallpapers" && pwd)"

pick_wallpaper() {
  for candidate in catpuccin.jpeg arch-start.png; do
    if [[ -f "$WALL_DIR/$candidate" ]]; then
      printf '%s' "$WALL_DIR/$candidate"
      return 0
    fi
  done
  return 1
}

if ! command -v xfconf-query >/dev/null 2>&1; then
  printf 'xfconf-query not found; is xfce4-settings installed?\n' >&2
  exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
  printf 'no DISPLAY; cannot set the backdrop now.\n' >&2
  printf 'Run from inside the Xfce session, or set it once after logging in.\n' >&2
  exit 1
fi

wall="$(pick_wallpaper)" || { printf 'no wallpaper found in %s\n' "$WALL_DIR" >&2; exit 1; }
printf 'setting backdrop: %s\n' "$wall"

# Workspaces are named loq-1..loq-N by config/xfce/xfce-perchannel-xml. A
# workspace that does not exist yet is silently ignored by xfconf, so this is
# tolerant rather than fatal.
workspaces=4
for n in $(seq 0 $((workspaces - 1))); do
  if xfconf-query -c xfce4-desktop -p "/backdrop/loq-$n/last-image" -n -t string -s "$wall" 2>/dev/null; then
    printf '  loq-%s\n' "$n"
  else
    printf '  skipped loq-%s (workspace not defined)\n' "$n"
  fi
done

# Zoom and style: Zoomed fills a 16:10 panel without letterboxing.
for n in $(seq 0 $((workspaces - 1))); do
  xfconf-query -c xfce4-desktop -p "/backdrop/loq-$n/image-style" -n -t int -s 1 2>/dev/null || true
  xfconf-query -c xfce4-desktop -p "/backdrop/loq-$n/color-style" -n -t int -s 0 2>/dev/null || true
  xfconf-query -c xfce4-desktop -p "/backdrop/loq-$n/show" -n -t bool -s true 2>/dev/null || true
done

printf '\nverify with: xfconf-query -c xfce4-desktop -p /backdrop -l\n'
