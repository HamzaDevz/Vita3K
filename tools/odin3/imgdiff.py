#!/usr/bin/env python3
# imgdiff.py <reference.png> <shot.png>: share of the picture that differs from a reference shot of the same scene.
# Calibrated on Uncharted's checkpoint shot: correct renders stay under 2%, broken upscaled ones go over 25%.
import sys

from PIL import Image, ImageChops


def small(path):
    return Image.open(path).convert("RGB").resize((96, 54), Image.BOX)


diff = ImageChops.difference(small(sys.argv[1]), small(sys.argv[2])).convert("L")
off = sum(1 for v in diff.get_flattened_data() if v > 40) / (96 * 54)
print(f"image {sys.argv[2].rsplit('/', 1)[-1][:-4]}: {off:.1%} off the reference"
      + (" BROKEN RENDER" if off > 0.10 else ""))
