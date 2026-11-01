#!/bin/sh
# Exports the draw.io figures of the documentation.
#
#   scripts/docs_figures.sh [figure.drawio ...]
#
# docs/figures/<name>.drawio is the source of each figure (edit it with
# draw.io desktop or the VS Code draw.io extension). This script writes
# <name>.svg (GitHub pages) and <name>.pdf (PDF manual) next to it, for every
# figure newer than its exports, or for the figures given as arguments.
# draw.io runs on the host (DRAWIO, default: drawio in PATH); the exports are
# committed, so building the manual needs no draw.io.
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
drawio=${DRAWIO:-drawio}
if ! command -v "$drawio" >/dev/null 2>&1; then
    echo "draw.io not found: install draw.io desktop (github.com/jgraph/drawio-desktop) or set DRAWIO" >&2
    exit 1
fi
if [ $# -eq 0 ]; then
    set -- "$root"/docs/figures/*.drawio
fi
for src in "$@"; do
    base=${src%.drawio}
    for fmt in svg pdf; do
        if [ ! -f "$base.$fmt" ] || [ "$src" -nt "$base.$fmt" ]; then
            echo "$(basename "$src") -> $(basename "$base.$fmt")"
            "$drawio" --no-sandbox -x -f $fmt --theme light --crop -b 8 -o "$base.$fmt" "$src" >/dev/null 2>&1
        fi
    done
done
