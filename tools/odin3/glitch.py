#!/usr/bin/env python3
# glitch.py <shot.png>...: blocks of pure black inside the picture, the mark of surfaces the renderer never wrote
# (Uncharted's big black squares), and neon green or blue, the same corruption read through another path. Needs no
# reference shot, so it judges every shot of a run. A frame black at more than 85% (load, fade) and clean edge-to-edge
# bars (cinematic letterbox) are not counted, a ragged black area eating the picture from an edge is. A hole is exact
# zero with a hard edge against the lit picture; a shadow fades into dark surroundings (calibrated on Uncharted's 35
# chapters). Neon is calibrated on 851 shots of Uncharted, Gravity Rush and Ninja Gaiden: at most 0.4% of the frame
# when correct, 14 to 20% with the corruption; red is left out, fire is that saturated.
import sys

import numpy as np
from PIL import Image

CELL = 8  # pixels of the 960-wide shot
MIN_CELLS = 16  # 1024 px, 0.2% of the frame
MIN_FILL = 0.7  # share of its bounding box a block fills: renderer holes are tiles, shadows are not
MIN_FILL_EDGE = 0.5  # a ragged area eating the picture from an edge
MAX_NEON = 0.02  # share of the frame


def hard_edge(peak, x, y, w, h):
    ring = [peak[max(0, y - 4):y, x:x + w], peak[y + h:y + h + 4, x:x + w],
            peak[y:y + h, max(0, x - 4):x], peak[y:y + h, x + w:x + w + 4]]
    ring = np.concatenate([r.ravel() for r in ring])
    return ring.size and np.mean(ring > 40) >= 0.13


def blocks(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)
    h, w = (rgb.shape[0] // CELL) * CELL, (rgb.shape[1] // CELL) * CELL
    full = rgb.max(axis=2)
    peak = rgb[:h, :w].max(axis=2).reshape(h // CELL, CELL, w // CELL, CELL).max(axis=(1, 3))
    black = peak <= 6
    zero = (full[:h, :w] == 0).reshape(h // CELL, CELL, w // CELL, CELL).mean(axis=(1, 3))
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
            # Letterbox bars are clean rectangles across the frame; status and menu bars hug one edge
            if len(cells) == bh * bw and (bw >= cols * 0.9 and (min(rs) == 0 or max(rs) == rows - 1)
                                          or bh >= rows * 0.9 and (min(cs) == 0 or max(cs) == cols - 1)):
                continue
            if (min(rs) == 0 or max(rs) == rows - 1) and bh <= 5 or (min(cs) == 0 or max(cs) == cols - 1) and bw <= 5:
                continue
            x, y = min(cs) * CELL, min(rs) * CELL
            # Exact zero is measured on the area itself, its bounding box also holds the picture it ate
            edge = min(rs) == 0 or max(rs) == rows - 1 or min(cs) == 0 or max(cs) == cols - 1
            exact = zero[tuple(zip(*cells))] if edge else zero[min(rs):max(rs) + 1, min(cs):max(cs) + 1]
            if (len(cells) >= MIN_CELLS and len(cells) / (bh * bw) >= (MIN_FILL_EDGE if edge else MIN_FILL)
                    and np.mean(exact) >= 0.75
                    and hard_edge(full, x, y, bw * CELL, bh * CELL)):
                found.append((x, y, bw * CELL, bh * CELL, len(cells)))
    return found, rows * cols


def neon(path):
    rgb = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    top = np.sort(rgb, axis=2)
    hot = (top[..., 2] >= 200) & (top[..., 2] - top[..., 1] >= 90) & (top[..., 2] - top[..., 0] >= 120)
    return np.mean(hot & (rgb.argmax(axis=2) > 0))


for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1][:-4]
    # One line per shot, so that run.sh counts broken shots
    issues = []
    share = neon(path)
    if share > MAX_NEON:
        issues.append(f"{share:.1%} of the frame in neon green or blue CORRUPT COLORS")
    res = blocks(path)
    if res is None:
        issues.append("black frame")
    elif res[0]:
        found, total = res
        share = sum(f[4] for f in found) / total
        where = " ".join(f"{w}x{h}@{x},{y}" for x, y, w, h, _ in sorted(found, key=lambda f: -f[4])[:4])
        issues.append(f"{len(found)} black blocks, {share:.1%} of the frame ({where}) BLACK BLOCKS")
    if issues:
        print(f"image {name}: {', '.join(issues)}")
