# 0099: The LOD demo scene in the app

Status: landed (2026-10-19, 10089ea)

Goal: a field of furnaces at many distances in the app only, each switching its level by 0096 to 0098 (user, 2026-10-19: "Lets keep it off the web, ill test it on the couch and laptop/desktop").

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh debug`, `./build.sh smoke` (runs the new demo too); the two new blobs 1 m high at their counts.

## Specification

- Two coarser levels, `poisson_3000.mesh` and `poisson_1500.mesh`, from `model_7_poisson.ply` through `decimate.py` and `mesh_blob.py --height 1` into `data/demos/decimation/meshes/` (the main agent bakes them).
- `data/demos/lod/scene.sjson` and `data/demos/lod/description.txt`, no package under `src/demos/` so no page: fly camera, a concrete slab, furnaces in five columns 3 m apart and rows from 2 m to 80 m in front of the start (about one row every 4 m), each with `levels` from `poisson_768000.mesh` down to `poisson_1500.mesh`, no labels.
- `src/app/demos.odin`: a `DECIMATION_MESHES :: #load_directory(...)` constant used by the decimation demo and a new `lod` entry, so the blobs are embedded once; the description loaded from `data/demos/lod/description.txt`. The usage line in `src/app/main.odin` and `doc/build.md` name `lod`.
- `build.sh`: `smoke_app` runs `--demo lod --frames 3` as a third run.
