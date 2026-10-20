# 0123: Baked vertex masks

Status: designed (2026-10-20)

Goal: the masks the design gives a model (DESIGN.md, Consistency comes from the renderer: "a model carries geometry, UVs, a material id per part and masks (wear, emissive)"), baked per vertex as steps: `occlusion` (ambient occlusion by rays), `curvature` (convex and concave edges, which the wear rule reads), `emissive` (from the brief's part roles, with strokes to add or remove).

Verify:
- `./build.sh test` with tests on small meshes (a cube's corners convex, a notch concave, a box inside a box occluded); the editor shows each mask as a grey scale on its machine (a toggle beside false colour); shots read by the main agent.

## Specification

- `Pipeline_Mesh` gains `masks: [dynamic][4]u8` per vertex (occlusion, curvature with 128 flat, emissive, spare); ops that make new geometry carry them by nearest source vertex.
- `occlusion {rays, distance}`: per vertex, cosine weighted rays over the hemisphere against the mesh through 0120's pick grid, the fraction unblocked within the distance. `curvature {radius}`: the mean of the normals' divergence over the neighbours within the radius, mapped to 0..255. `emissive {part role or select, value}`: the brief's `role = "emissive"` parts at 255 by default.
- Each level of a `levels` mesh is baked on its own triangles.
