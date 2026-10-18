# 0045: The blockout masks' row order

Status: verified (2026-10-18)

Goal: the masks of item 0042 are written upside down, which the review sheet of item 0044 found on its calibration (the hero mask against the hero render scored 0.16 as stored and 0.62 flipped). `images.write_png` takes its rows bottom first, the bake's convention, and `threshold_mask` hands it the reader's top first rows. Follow-up of item 0042.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` re-renders, and `hero_mask.png` shows the stack at the top and the base at the bottom, as `hero.png` does.
