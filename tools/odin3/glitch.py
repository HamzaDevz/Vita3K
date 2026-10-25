#!/usr/bin/env python3
# glitch.py <shot.png>...: blocks of pure black inside the picture, the mark of surfaces the renderer never wrote
# (Uncharted's big black squares). Needs no reference shot, so it judges every shot of a run. A frame black at more
# than 85% (load, fade) and edge-to-edge bars (cinematic letterbox) are not counted.
import sys

import numpy as np
from PIL import Image

CELL = 8  # pixels of the 960-wide shot
MIN_CELLS = 16  # 1024 px, 0.2% of the frame
MIN_FILL = 0.7  # share of its bounding box a block fills: renderer holes are tiles, shadows are not


def blocks(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)
    h, w = (rgb.shape[0] // CELL) * CELL, (rgb.shape[1] // CELL) * CELL
    peak = rgb[:h, :w].max(axis=2).reshape(h // CELL, CELL, w // CELL, CELL).max(axis=(1, 3))
    black = peak <= 6
    rows, cols = black.shape
    if black.mean() > 0.85:
        return None
    seen = np.zeros_like(black)
    found = []
    for r0 in range(rows):
        for c0 in range(cols):
            if not black[r0, c0] or seen[r0, c0]:
                continue
            todo, cells = [(r0, c0)], []
            seen[r0, c0] = True
            while todo:
                r, c = todo.pop()
                cells.append((r, c))
                for rr, cc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                    if 0 <= rr < rows and 0 <= cc < cols and black[rr, cc] and not seen[rr, cc]:
                        seen[rr, cc] = True
                        todo.append((rr, cc))
            rs, cs = [r for r, _ in cells], [c for _, c in cells]
            bh, bw = max(rs) - min(rs) + 1, max(cs) - min(cs) + 1
            # Letterbox bars span the frame; status and menu bars hug one edge
            if bw >= cols * 0.9 or bh >= rows * 0.9:
                continue
            if (min(rs) == 0 or max(rs) == rows - 1) and bh <= 5 or (min(cs) == 0 or max(cs) == cols - 1) and bw <= 5:
                continue
            if len(cells) >= MIN_CELLS and len(cells) / (bh * bw) >= MIN_FILL:
                found.append((min(cs) * CELL, min(rs) * CELL, bw * CELL, bh * CELL, len(cells)))
    return found, rows * cols


for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1][:-4]
    res = blocks(path)
    if res is None:
        print(f"image {name}: black frame")
        continue
    found, total = res
    if found:
        share = sum(f[4] for f in found) / total
        where = " ".join(f"{w}x{h}@{x},{y}" for x, y, w, h, _ in sorted(found, key=lambda f: -f[4])[:4])
        print(f"image {name}: {len(found)} black blocks, {share:.1%} of the frame ({where}) BLACK BLOCKS")
