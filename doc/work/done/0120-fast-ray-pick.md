# 0120: A fast ray pick

Status: landed (2026-10-20, 2d862ce)

Goal: the brush's ray pick in microseconds instead of 19 ms (release) or 300 ms (debug), since the brush picks on every frame the crosshair moves.

Verify:
- `./build.sh test` with tests that the indexed pick equals the plain loop's on random rays over a test mesh; a timing printed once by a test on a synthetic 1.5 M triangle mesh.

## Specification

- `src/pipeline/pipeline_pick.odin`: `Pick_Grid` (a uniform grid over the mesh's bounds, cells of about 64 triangles on average, each cell the triangles whose bounds overlap it), `pick_grid_build(mesh)`, `pick_grid_ray(grid, mesh, origin, direction)` walking the cells along the ray (3D DDA) and stopping at the first cell holding a hit nearer than the next cell's entry. The editor builds one per machine it brushes, when the output changes. The plain `ray_pick` stays as the reference for the test.
