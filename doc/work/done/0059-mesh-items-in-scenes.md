# 0059: Mesh items in scenes

Status: landed (2026-10-19, c5f2af4)

Goal: a scene item can be a mesh blob from a file (item 0058's format) beside the box, cylinder and room, so a demo page can show generated models.

Verify:
- `./build.sh test` passes with the new tests: `test_parse_mesh_blob_reads_a_triangle` (a blob built in the test with `BAMESH01`, three vertices, three indices parses to the same numbers), `test_parse_mesh_blob_rejects_a_bad_magic_and_a_short_file`, `test_mesh_half_extents` (the triangle's extents), `test_parse_scene_reads_a_mesh_item` (a scene with `{ shape = "mesh", file = "part.mesh", scale = 2, position = [0, 0, 0], material = "painted_steel" }` parses with `.Mesh`, the file name and the scale) and `test_parse_scene_rejects_a_mesh_item_without_a_file`.
- `./build.sh check` passes; `./build.sh web light` builds, the three existing demos pass an empty mesh list.

## Specification

- `src/engine/render_mesh_blob.odin`: `MESH_BLOB_MAGIC :: "BAMESH01"`, `parse_mesh_blob(data: []byte, allocator := context.allocator) -> (mesh: Mesh_Data, problem: string)`: checks the magic and that the length is 16 plus 24 per vertex plus 4 per index, copies the vertices and the indices out of the little endian bytes (`endian.unchecked_get_u32le` and `transmute` of the f32 bits, or `intrinsics.unaligned_load` of the structs, whichever is cleaner), and rejects an index at or past the vertex count; the problem names what is wrong. `mesh_half_extents(mesh: Mesh_Data) -> [3]f32`, the half extents of the smallest box centred on the origin that holds the vertices (the box the shader's edge distance assumes), pure.
- `src/engine/scene.odin`: `Scene_Shape` gains `.Mesh`; `Scene_Item` gains `file: string` (the blob's file name) and `scale: f32` (default 1 for every shape); `parse_scene_item` reads `shape = "mesh"` with a required `file` and an optional positive `scale`, the doc comment and the error text listing the four shapes. `scene_item_mesh(item, meshes: []runtime.Load_Directory_File) -> (Mesh_Data, problem)` finds the `.Mesh` item's file by name (as `texture_file_find` does) and parses it, the problem naming a missing file; the other shapes as now. `scene_item_half_extents(item, mesh: Mesh_Data)` returns the parsed mesh's half extents for `.Mesh`, unscaled since the shader compares them with the vertex position before the model matrix, as now for the others. The draw transform of an item is the translation times a uniform scale.
- `src/engine/web_scene_page.odin`: `scene_page_init` gains `meshes: []runtime.Load_Directory_File` after `textures`; `scene_page_upload_meshes` passes them, keeps each item's half extents in a new `item_half_extents: [][3]f32` from the parsed mesh before destroying it, and fails the init with the mesh problem; `scene_page_step` uses the kept half extents and `linalg.matrix4_translate_f32(item.position) * linalg.matrix4_scale_f32({item.scale, item.scale, item.scale})`.
- `src/demos/light/main.odin`, `cave`, `surface`: pass `nil` for the meshes.
- `doc/render.md`, Scene files: the `"mesh"` shape with `file` and `scale`, the blob directory passed to `scene_page_init` through `#load_directory`, and the format's pointer to `doc/workflows/models.md`.
