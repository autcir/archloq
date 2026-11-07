#!/usr/bin/env python3
"""Generate the XPM assets for the xfwm4 `mocha` theme.

xfwm4 reads button artwork as XPM (C-source with a colour table), not PNG. The
`full_width_title=true` setting in themerc means the titlebar itself is drawn
from themerc colours and needs no images, so the only assets xfwm4 actually
looks for are the window buttons and the menu icon.

Run from scripts/20-xfce.sh when the palette changes:
    python3 tools/gen-xfwm4-theme.py dotfiles/config/xfwm4/themes/mocha
"""

from __future__ import annotations

import pathlib
import sys

# Catppuccin Mocha. Keep in sync with themerc beside the generated files.
CRUST = "#11111b"
MANTLE = "#181825"
SURFACE0 = "#313244"
SURFACE1 = "#45475a"
SURFACE2 = "#585b70"
TEXT = "#cdd6f4"
RED = "#f38ba8"
YELLOW = "#f9e2af"
GREEN = "#a6e3a1"
BLUE = "#89b4fa"

SIZE = 16


def xpm(name: str, grid: list[list[str | None]]) -> str:
    """Render a pixel grid as a valid XPM3 C array.

    `grid` holds colour strings or None for transparent. Colours are emitted
    into the XPM colour table in first-seen order and referenced by their
    single-character keys.
    """
    height = len(grid)
    width = len(grid[0])
    if any(len(row) != width for row in grid):
        raise ValueError(f"{name}: ragged grid")

    keys: dict[str, str] = {"None": "None"}
    order: list[str] = []
    for row in grid:
        for pixel in row:
            if pixel is not None and pixel not in keys:
                keys[pixel] = chr(ord("c") + len(order))
                order.append(pixel)

    lines = [
        "/* XPM */",
        f"static char * {name}_xpm[] = {{",
        f'"{width} {height} {len(order)} 1",',
    ]
    for colour in order:
        lines.append(f'"{keys[colour]} c {colour}",')

    key_for = lambda px: keys["None"] if px is None else keys[px]  # noqa: E731
    rows = ["".join(key_for(px) for px in row) for row in grid]
    if len(order) + 1 < 10:
        rows = [f" {row}" for row in rows]
    lines.extend(f'"{row}",' for row in rows)
    lines.append("};")
    return "\n".join(lines) + "\n"


def blank(fill: str | None) -> list[list[str | None]]:
    return [[fill] * SIZE for _ in range(SIZE)]


def close_glyph(base: str, tint: str) -> list[list[str | None]]:
    grid = blank(base)
    for i in range(4, SIZE - 4):
        grid[i][i] = tint
        grid[i][SIZE - 1 - i] = tint
    return grid


def maximize_glyph(base: str, tint: str) -> list[list[str | None]]:
    grid = blank(base)
    for x in range(3, SIZE - 3):
        grid[3][x] = tint
        grid[SIZE - 4][x] = tint
    for y in range(3, SIZE - 3):
        grid[y][3] = tint
        grid[y][SIZE - 4] = tint
    return grid


def hide_glyph(base: str, tint: str) -> list[list[str | None]]:
    grid = blank(base)
    for x in range(3, SIZE - 3):
        grid[SIZE - 4][x] = tint
    return grid


def menu_glyph(base: str, tint: str) -> list[list[str | None]]:
    grid = blank(base)
    for y in (4, 7, 10):
        for x in range(3, SIZE - 3):
            grid[y][x] = tint
    return grid


GLYPHS = {
    "close": (close_glyph, RED),
    "maximize": (maximize_glyph, YELLOW),
    "hide": (hide_glyph, GREEN),
}

# xfwm4 expects `-active`/`-inactive` variants; hover and pressed states are
# recoloured by themerc, so only the two resting states are shipped.
STATES = {"active": (SURFACE1, None), "inactive": (SURFACE0, MANTLE)}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} OUTPUT_DIR", file=sys.stderr)
        return 2
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    for button, (draw, tint) in GLYPHS.items():
        for state, (base, _) in STATES.items():
            name = f"{button}-{state}"
            (out / f"{name}.xpm").write_text(xpm(name, draw(base, tint)), encoding="ascii")
            written.append(name)
    (out / "menu.xpm").write_text(xpm("menu", menu_glyph(MANTLE, TEXT)), encoding="ascii")
    written.append("menu")

    print(f"wrote {len(written)} XPM assets to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())