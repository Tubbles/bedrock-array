# 0095: Smooth shaded decimations

Status: landed (2026-10-19, f2384f6)

Goal: the Blender decimations share their vertices instead of carrying three per triangle, so the blobs shrink before the LOD demo multiplies them (user, 2026-10-19: "make all the items for the LOD demo after the indexed blob format, which you can do next"). The blob format already has an index buffer; the flat shading of Blender's export split every vertex.

Verify:
- Every rebaked blob 1 m high with its old triangle count and fewer vertices; `./build.sh web models`, `./build.sh web decimation`, `./build.sh smoke`.

## Specification

- `tools/models/decimate.py` shades the parts smooth by angle (`SMOOTH_ANGLE_DEGREES = 30`) after the decimate.
- Every blob made through it is rebaked: the four plain Blender decimations and the 36 closed variants of the models demo, and the decimation demo's levels (`tmp/smooth/rebake.sh`, recorded in the commit message).
- `doc/workflows/models.md` says the decimations are smooth shaded by angle.
