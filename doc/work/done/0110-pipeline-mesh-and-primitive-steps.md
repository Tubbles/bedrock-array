# 0110: The pipeline's mesh and its primitive steps

Status: landed (2026-10-20, 488bc6f)

Goal: the in memory mesh of the asset pipeline and the steps that run natively: transform, weld, the selections, assign, delete and copy (doc/workflows/pipeline_editor.md). First of 0110 to 0116 (user, 2026-10-20: "I want the whole thing immediately").

Verify:
- `./build.sh test` runs the new package's tests and they pass; `./build.sh check` covers the package.

## Specification

- New package `src/pipeline/` (`package pipeline`, native only, files `#+build !js`), added to `build.sh check` and `build.sh test` beside the engine and the app.
- `pipeline_mesh.odin`: `Pipeline_Mesh {positions, normals: [dynamic][3]f32, triangles: [dynamic][3]u32, pieces: [dynamic]u32 (one per triangle), parts: [dynamic]u16 (one per triangle, PART_NONE :: max(u16)), piece_names, part_names: [dynamic]string}`, `pipeline_mesh_clone`, `pipeline_mesh_destroy`, `pipeline_mesh_bounds`, `pipeline_mesh_part_index(mesh, name) -> (u16, bool)` (adding the name when asked).
- `pipeline_steps.odin`, pure procedures on a mesh: `step_transform(mesh, front: Front, height: f32)` (`Front :: enum {Plus_X, Minus_X, Plus_Z, Minus_Z}`, the quarter turn that brings `front` to +z as in `tools/models/parts.py`'s `turn`, ground and scale as there), `step_weld(mesh, metres)` (merge by a spatial hash of cells of that size, keeping the first vertex, dropping triangles that become degenerate), `select_triangles(mesh, select: Select) -> []bool` with `Select {kind: Select_Kind (Pieces, Part, Box, Sphere, Strokes), pieces: []string, part: string, minimum, maximum, centre: [3]f32, radius: f32, strokes: []Stroke {position: [3]f32, radius: f32}, within_part: string}` (a triangle counts by its centroid), `step_assign(mesh, part, selected)`, `step_delete(mesh, selected)` (compacting unused vertices), `step_copy(mesh, selected, from, to: [3]f32, turn: int)` (a new piece named `copy_<n>`, normals turned too), `stroke_triangle_counts(mesh, strokes) -> []int`.
- `pipeline_steps_test.odin`: one test per step on small hand built meshes (two quads as two pieces): `test_transform_turns_grounds_and_scales`, `test_weld_merges_close_vertices_and_drops_degenerate_triangles`, `test_select_by_each_kind`, `test_select_within_part_narrows`, `test_assign_sets_the_part`, `test_delete_compacts`, `test_copy_turns_and_moves_into_a_new_piece`, `test_stroke_counts`.
