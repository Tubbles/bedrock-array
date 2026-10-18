# 0054: Renders filling the frame

Status: landed (2026-10-19, 72490e8)

Goal: the blockout renders leave much of their frame empty (the smelter's elevations span about 59 percent of the width, the hero 76 percent of the height), which halves the small parts twice over in the collage's panels (user, 2026-10-19: "make the renders fill in their panels more"). Every render frames the machine with a small margin, the four elevations at one shared scale so the turnaround stays true.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` renders; with PIL, `front_mask.png`'s bounding box spans about 82 percent of the width, `right_mask.png`'s about 87 percent (the depth with the sill standing proud of the front is the largest extent, so it sets the shared scale), `hero_mask.png`'s about 86 percent of the height, the narrowest margin about 4 percent, nothing touching an edge.
- `python3 tools/art/concept.py smelter --collage --round 10 --dry-run` writes a sheet whose panels the renders fill likewise.

## Specification

- `tools/art/blockout.py`: `HERO_MARGIN = 0.05`. `orthographic_scale(parts)` takes the parts' world bounding box through `bounding_corners(parts)`, the largest of its three extents, times `ORTHOGRAPHIC_SCALE_FACTOR = 1.15`; `add_orthographic_camera(name, side, brief, parts)` and `add_cameras` pass the parts; the camera target stays at half the brief's height. The constants' comments say what they are: the hero's margin as a share of the frame on each side, the elevations' frame as a factor of the machine's largest extent, shared by the four views.
- `doc/workflows/art_book.md`, step 2: one clause that the renders frame the machine with a small margin, the four elevations at one scale.
