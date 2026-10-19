# 0058: The mesh blob tool

Status: landed (2026-10-19, b8b9c3b)

Goal: the four Tripo variants of the smelter are to stand side by side on a tech demo page (user, 2026-10-19), and the engine draws `Mesh_Data` (positions, normals, u32 indices) it builds itself, nothing from a file. A tool turns a GLB into the engine's flat mesh blob, one mesh per file, scaled and grounded for the scene.

Verify:
- `python3 tools/models/mesh_blob.py work/models/smelter/model_7_faces12000.glb tmp/faces12000.mesh --height 1.0` prints the vertex count, the index count (3 times 10700) and the bounds, the file is 16 bytes plus 24 bytes per vertex plus 4 per index, and the printed bounds span 1.0 in y from 0 up with x and z centred on 0.
- The same on `work/models/smelter/model_7.glb` gives 1461245 times 3 indices.
- `python3 -c` reading the header back with `struct` gives the magic, the counts and the first vertex within the bounds.

## Specification

- `tools/models/mesh_blob.py <glb> <out.mesh> [--height <metres>]`, stdlib only (`struct`, `json`, `argparse`). Reads the GLB's JSON and binary chunks; for every node with a mesh, takes its primitives' `POSITION` and `NORMAL` accessors (VEC3 float, through their buffer views with `byteOffset` and `byteStride` honoured) and `indices` (UNSIGNED_SHORT or UNSIGNED_INT), applies the node's `translation`, `rotation` (quaternion) and `scale` to positions and the rotation to normals (nodes without parents only, these GLBs have a flat list; a `matrix` on a node is an error), and appends them to one vertex list and one index list with the index offset. Then grounds and scales: the bounding box's bottom centre goes to the origin, and with `--height` every position is multiplied by height over the box's y extent. Writes the blob: the magic bytes `BAMESH01`, u32 vertex count, u32 index count, the vertices as six little endian f32 each (position then normal), the indices as u32. Prints `<out>: <vertices> vertices, <indices> indices, bounds [x0 y0 z0] to [x1 y1 z1]`. Procedures: `read_glb`, `read_accessor`, `node_transform`, `gather_meshes`, `ground_and_scale`, `write_blob`, `main`, each small and pure where it can be.
- `.gitattributes`: `*.mesh filter=lfs diff=lfs merge=lfs -text` under the Models heading.
- `doc/workflows/models.md`, Files: one line for the blob, `data/demos/<demo>/meshes/<name>.mesh`, the engine's flat mesh for a demo page, made by the tool from a GLB, and the format in one sentence.
