# 0091: The decimation demo orbits its furnaces by Poisson depth

Status: landed (2026-10-19, 01b5c5b)

Goal: the decimation demo (0087) orbits one furnace at a time, the arrows step to the next level of detail (0093), and the configurations cycle the Poisson depth of the closing the levels were decimated from (user, 2026-10-19: "lets run the depths 6 to 8, make it configurable and so i can toggle it around while zoomed in at various details").

Verify:
- `./build.sh web decimation`, `./build.sh smoke`, the app run headless with `--demo decimation --frames 3`; every blob 1 m high.

## Specification

- `tools/models/reconstruct.py` takes `--depth` (default 9). The blobs: `poisson_depth<d>.mesh` (the plain closing at depth 8, 7, 6) and `poisson_depth<d>_<count>.mesh` for each level below that closing's own count, made by `tmp/decimation/bake_depths.sh` (recorded in the commit message).
- `data/demos/decimation/scene.sjson`: camera `mode = "orbit"`, `target = [-5.6, 0.5, 0]` (the full model's middle), `distance = 2.5`, `pitch = 0.35`, no `fit_width`; `configurations = ["Poisson depth 9", "Poisson depth 8", "Poisson depth 7", "Poisson depth 6"]`; the full item keeps `file`, each level item gets `files` in depth order, depth 9 the existing `poisson_<count>.mesh`, and a depth whose closing has no more triangles than the level uses its plain `poisson_depth<d>.mesh`. The labels name the level and say where a depth falls back to its plain closing only in the scene comment.
- `src/demos/decimation/description.txt`: the orbit controls (drag, wheel, pinch, the arrows and d-pad for the next level, C, North, the shoulders and the buttons for the depth).
