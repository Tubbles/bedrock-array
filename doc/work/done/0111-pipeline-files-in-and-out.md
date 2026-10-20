# 0111: The pipeline's files in and out

Status: landed (2026-10-20, ef7d36e)

Goal: the pipeline reads a generated GLB into its mesh (each root node a piece) and writes PLY for the external tools, reads their PLY or GLB back, and writes the engine's mesh blobs per part.

Verify:
- `./build.sh test` with the new tests; reading `work/models/smelter/model_7.glb` gives 29 pieces and 1461245 triangles (a test skipped when the file is absent).

## Specification

- `src/pipeline/pipeline_glb.odin`: `read_glb(data: []byte) -> (Pipeline_Mesh, problem: string)`: the GLB container (magic, JSON chunk through `core:encoding/json`, BIN chunk), every root node with a mesh, its node transform (translation, rotation, scale, as `tools/models/mesh_blob.py`'s `node_transform`), every primitive's POSITION, NORMAL (computed per face when absent) and indices (u8, u16, u32; none means a triangle list), as one piece per root node named by the node. Errors name what is missing.
- `src/pipeline/pipeline_ply.odin`: `write_ply(path, mesh, selected)` (binary little endian, x y z nx ny nz floats, faces as a uchar count and int indices, the format `tools/models/parts.py` writes) and `read_ply(data) -> (Pipeline_Mesh, problem)` reading that format and MeshLab's (vertex properties in any order with double `quality` skipped, faces as uchar and int or uint).
- `src/pipeline/pipeline_blob.odin`: `write_part_blobs(mesh, directory, suffix)`: one `BAMESH01` blob per part, `<part><suffix>.mesh`, positions as they are.
- Tests: `test_read_glb_of_a_hand_built_document`, `test_ply_round_trip`, `test_read_meshlab_ply_with_quality`, `test_part_blobs_split_by_part`, `test_read_the_smelter_model` (skipped without the file).
