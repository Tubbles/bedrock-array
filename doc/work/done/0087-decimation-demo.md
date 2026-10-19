# 0087: The decimation demo

Status: landed (2026-10-19, 6321c29)

Goal: a new scene that compares the full model with Blender decimations of its Poisson closing at 768000, 384000, 192000, 96000, 48000, 24000 and 12000 triangles in one row (user, 2026-10-19: "blender decimation from full 1.4M model with poisson is the one that comes the closest", "lets keep this one as is now"). Follows 0085. The models demo stays unchanged.

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh web decimation`, `./build.sh smoke`; every blob is 1 m high with its target count.

## Specification

- `src/demos/decimation/` (a copy of the models package), `data/demos/decimation/scene.sjson` and `meshes/` (`full.mesh` copied from the models demo, `poisson_<count>.mesh` made by Blender's `decimate.py` from `model_7_poisson.ply` and `mesh_blob.py --height 1`), the app's menu entry in `src/app/demos.odin`, the usage line and `doc/build.md`.
