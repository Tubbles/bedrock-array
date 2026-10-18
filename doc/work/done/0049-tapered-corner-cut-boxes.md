# 0049: Tapered and corner cut boxes

Status: landed (2026-10-19, c5a5c97)

Goal: the bevels of item 0048 round the smelter's edges but leave it a stack of cubes (user, 2026-10-19: "cut up the literal cubeiness of it, make it slant inwards slightly towards the top, cut out the corners of the upper body"). A box may taper toward its top and have its vertical edges chamfered, and the smelter's body and lid use both.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` renders, and `work/art/smelter/blockout/hero.png` shows the body's sides slanting in toward the top, its four vertical corners cut to an octagonal plan, the lid the same, the hearth frame still proud of the front face, the mask solid.
- `front.png` shows the body and the lid as trapezoids, narrower at the top.
- A box without `taper` or `corner_cut` renders as before.

## Specification

- `tools/art/blockout.py`, `add_box_shape`: two optional keys on a box shape, `taper` (the top face's width and depth as a factor of the bottom's, 1 is none) and `corner_cut` (metres chamfered off each vertical edge, one flat cut). After the scale is set, apply it in the builder (`bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)`), then edit the mesh with bmesh: `cut_corners(mesh, cut)` bevels the vertical edges (both vertices at the same x and y, Blender's z is up) with `bmesh.ops.bevel(editable, geom=vertical_edges, offset=cut, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES")`; `taper_top(mesh, taper)` scales the x and y of every vertex above the mesh's centre (z > 0, the primitive is centred) by the factor. Corner cut first, then taper, so the chamfer's top vertices taper with the rest. The 0048 `add_bevel` modifier still runs after, in `add_part`, and its 30 degree angle limit rounds the chamfer's edges too, which is wanted. Follow `delete_lower_half` for the bmesh in and out.
- `data/machines/smelter/brief.sjson`: `body` becomes `size = [0.9, 0.5, 0.9] position = [0, 0.6, 0]` with `taper = 0.94 corner_cut = 0.12` and its bevel; `lid` becomes `size = [0.5, 0.1, 0.5] position = [0, 0.9, 0]` with `taper = 0.85 corner_cut = 0.06` and its bevel; `skirt` becomes `size = [1.0, 0.35, 1.0] position = [0, 0.175, 0]` with `taper = 0.97` and its bevel. The hearth moves onto the body: the four `hearth_frame` bars at z 0.47, top `[0.5, 0.07, 0.08]` at `[0, 0.785, 0.47]`, bottom `[0.5, 0.07, 0.08]` at `[0, 0.415, 0.47]`, left `[0.07, 0.3, 0.08]` at `[-0.215, 0.6, 0.47]`, right at `[0.215, 0.6, 0.47]`; `hearth` `[0.36, 0.3, 0.06]` at `[0, 0.6, 0.455]`; `sill` `[0.5, 0.04, 0.12]` at `[0, 0.36, 0.5]`; `louvre` bars at x -0.435, y 0.72, 0.77, 0.82, z 0.2; `vents` at z 0.505. Every bevel gets `segments = 1`, a chamfer, not a fillet (user, 2026-10-19). The header comment names the two keys beside `bevel`.
- `doc/workflows/art_book.md`, Files, the brief line: beside the optional `bevel`, a `box` may carry `taper` and `corner_cut`.
- The review's finding: the auto smooth at 30 degrees shaded the chamfers round, since the bevel modifier splits a 45 degree corner into two edges under 30. The angle is now 10 degrees (`AUTO_SMOOTH_DEGREES`), under which only a cylinder's facets fall.
