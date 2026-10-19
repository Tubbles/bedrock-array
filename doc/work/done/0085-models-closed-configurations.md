# 0085: The models scene with the closing configurations

Status: landed (2026-10-19, 4e902fc)

Goal: the models demo cycles through the hole closing techniques (none, fill holes, voxel remesh, Poisson, alpha wrap) on every low poly model, with the base models unchanged, so each technique can be judged against the plain decimation at the same triangle count (user, 2026-10-19: "keep the plain decimations as intermediate steps"). Follows 0081 to 0084.

Verify:
- `./build.sh web models` builds and `./build.sh smoke` passes; the 36 blobs of 0081's batch exist under `data/demos/models/meshes/` and every `files` entry names one.

## Specification

- `data/demos/models/scene.sjson`: `configurations = ["none", "fill holes", "voxel remesh", "Poisson", "alpha wrap"]`; each of the nine low poly items gets `files = ["<blob>.mesh", "<blob>_fill.mesh", "<blob>_voxel.mesh", "<blob>_poisson.mesh", "<blob>_alphawrap.mesh"]` in that order; the two base items keep `file`. The labels stay (the counts are the plain configuration's, the others are decimated to the same count), the comment says so.
- `src/demos/models/description.txt`: one sentence on the configurations and how to cycle them (C, the pad's North button, the button on the page).
- The 36 blobs through Git LFS, made by the main agent with `tools/models/close_all.sh`.
