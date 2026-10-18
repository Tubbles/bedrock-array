# 0048: Bevels on blockout shapes

Status: verified (2026-10-18)

Goal: the smelter's blockout of item 0042 reads as stacked boxes (user, 2026-10-18: "too blocky, it needs chamfers, cylinders, etc, more polys"). Any shape of a brief may carry a bevel, so edges chamfer or round, and the smelter's brief uses it, with its hearth mouth rebuilt as a frame of four bars around a recessed glowing face.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` renders, and `work/art/smelter/blockout/hero.png` shows rounded edges on the skirt, the body and the lid, and the hearth as a framed mouth with its glow set back.
- A shape without `bevel` renders as before.

## Specification

- `tools/art/blockout.py`: a shape may carry `bevel = { width = <metres> segments = <count> }`. In `add_part`, after the builder returns the object, apply its scale (`bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)`, the box and the dome are scaled primitives, so a modifier added before would bevel in the unscaled space) and, when the shape has `bevel`, add a bevel modifier: `modifiers.new("bevel", "BEVEL")`, `width`, `segments`, `limit_method = "ANGLE"`. One small procedure, `add_bevel(part_object, bevel)`. The modifier renders in the views and the masks alike.
- `data/machines/smelter/brief.sjson`: `skirt` bevel 0.03 m, 3 segments; `body` 0.04 m, 3; `lid` 0.02 m, 2; `sill` 0.01 m, 1. `hearth_frame` becomes a list of four bars, each `box` 0.08 m deep at z 0.49, with bevel 0.02 m, 2: top `[0.5, 0.07, 0.08]` at `[0, 0.715, 0.49]`, bottom the same at `[0, 0.285, 0.49]`, left `[0.07, 0.36, 0.08]` at `[-0.215, 0.5, 0.49]`, right at `[0.215, 0.5, 0.49]`. `hearth` becomes `[0.36, 0.36, 0.06]` at `[0, 0.5, 0.48]`, its face 2 cm behind the frame's and 1 cm in front of the skirt's (the review found a face at 0.44 buried in the skirt below y 0.4). The header comment's shape sentence gains the bevel key.
- `doc/workflows/art_book.md`, Files, the brief line: `parts` carry a `blockout`, one shape or a list (`box`, `cylinder`, `dome`), each with an optional `bevel = { width, segments }`.
