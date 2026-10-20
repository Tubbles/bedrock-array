# 0122: The level of detail chain as a step

Status: designed (2026-10-20)

Goal: a `levels` op that turns the finished mesh into the game's chain of levels, each part decimated to its share of every level, so the line ends in what the LOD demo draws.

Verify:
- `./build.sh test`; the smelter's `levels` with `triangles = [192000, 96000, 48000, 24000, 12000, 3000, 1500]` runs through Blender on the worker and every level's parts sum to its count within a few triangles; the editor draws the levels side by side.

## Specification

- `Pipeline_Mesh` gains `levels: [dynamic]u8`, one per triangle (0 the finest); every op before keeps 0. `levels` decimates level 0 to each count per part (0112's decimate task per part per level), level n built from level 0 (not from level n minus 1), and stacks the results in one mesh with their level index.
- The editor draws a levels machine as one machine per level in a row across the line, finest first, each with its triangle count on the plaque.
- `doc/workflows/pipeline_editor.md`: the op row and the level index.
