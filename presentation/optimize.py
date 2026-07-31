#!/usr/bin/env python3
"""Shrink captured screenshots to web size, PNG -> JPEG.

The simulator writes 1179x2556 PNGs at ~2 MB each. The presentation renders a
phone about 324pt wide, so 760px covers a 2x display with room to spare. PNG
handles the crayon texture badly (it is noise, not flat colour), so these go out
as quality-90 JPEG: visually identical at this size, roughly 6x smaller, and
small enough that the screenshots can live in git beside the code that made them.
"""
import os
import glob
from PIL import Image

TARGET_W = 760
QUALITY = 90
HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, "shots")


def main():
    total_before = total_after = 0
    touched = 0
    for path in sorted(glob.glob(os.path.join(SHOTS, "*.png"))):
        name = os.path.basename(path)
        if name.startswith("_"):        # contact sheets, scratch
            continue
        before = os.path.getsize(path)
        out = path[:-4] + ".jpg"
        with Image.open(path) as im:
            w = min(im.width, TARGET_W)
            h = round(im.height * w / im.width)
            im.convert("RGB").resize((w, h), Image.LANCZOS).save(
                out, "JPEG", quality=QUALITY, optimize=True, progressive=True
            )
        os.remove(path)
        total_before += before
        total_after += os.path.getsize(out)
        touched += 1

    if touched:
        print("  optimized {} shots: {:.1f} MB -> {:.1f} MB".format(
            touched, total_before / 1e6, total_after / 1e6))


if __name__ == "__main__":
    main()
