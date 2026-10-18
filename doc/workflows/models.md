# The modelling workflow

The third asset workflow (definition.md, lesson 3, pipeline 5): how a machine's finished model is made from its concept turnaround, and how it is judged. Decided 2026-10-18 with item 0038, the research behind it in `doc/log/2026-10-18.md`. Waits for the Tripo account (SUGGESTIONS.md).

## The pipeline

The accepted turnaround (front, left, back, right) goes to Tripo's multiview to model API (`v3.1-20260211`) with `generate_parts = true`, `texture = false`, `pbr = false` and a fixed `model_seed`, which returns segmented, untextured geometry: the model carries no baked look, as DESIGN.md's consistency rule wants, so nothing has to be stripped. A headless Blender script then does what no generator does: the scale, the part mapping to the brief, the cleanup, the UVs, the masks, the cue pivots and sockets, the export. A segmentation task (`/v3/mesh/segment` with the hero as the reference image) is the fallback when the parts come back wrong.

What was not verified: no generator output of a squat drum machine was seen, and hard surface rankings come from vendor blogs. The smelter is the test. Soft edges send it to Tripo's retopology or to Meshy on the same turnaround.

## Files

- `work/models/<id>/`: the generated GLB with a sidecar (task id, seed, versions, cost), untracked.
- `data/models/<id>.glb`: the finished model, glTF 2.0, metres, Y up, through Git LFS, with `data/models/<id>.sjson` beside it (the source task, seeds, generator versions, the triangle count). It holds one node and mesh per part named by the part, each part's material named by its library preset id with no textures, `TEXCOORD_0`, `COLOR_0` with R curvature, G ambient occlusion, B the emissive mask, A reserved for a wear bias, node extras `{ part, material, cue }`, pivot nodes for the cues with `{ cue, axis, range_deg }`, and socket empties with `{ socket, cue }`. The engine decides how a cue drives these; the model only names them.

## The steps

1. `tools/models/generate.py <id>`: the multiview request with the four kept views, the poll, the download into `work/models/<id>/`.
2. `flatpak run org.blender.Blender -b --python "$PWD/tools/models/finish.py" -- <id>`: import, apply transforms, scale to the brief's height with the origin at the footprint's bottom centre, map the generated parts to the brief's parts (a part id pass from the hero camera, each part's median colour against the concept's pixels, the nearest brief part, an override table in the brief for the rest), merge by distance, delete loose geometry, recalculate normals, weighted normals, decimate to the brief's budget, cut the lid by a plane at the brief's height when it was not separated and set its origin on the hinge, smart project and pack the UVs per part, bake ambient occlusion and curvature to colour attributes, the emissive mask from the part role graded by the concept's glow, the socket empties, the export.
3. Review sheet: `work/models/<id>_review.png`, the hero and four orthographic renders in library materials under the material sheet's light beside the concept at the same camera, the figure, the wireframe, the parts and each mask in false colour, and the idle, working and venting frames. The checks: the bounding box against the footprint and height within a few percent, the triangles within budget, every brief part present with an existing library preset, no non manifold or loose geometry, UVs inside 0 to 1 without overlap, the mask ranges, the silhouette overlap of the orthographic renders against the turnaround, a pivot or socket for every cue of the brief. The user's eye decides.

## Rejected

- A scripted kit of primitives as the finished model: crisp edges and exact parts, and the programmer art lesson 1 forbids. It stays the blockout and the placeholder.
- Meshy: its parts mode is the older topology option, no multiview on its API page, the licence unread. Kept as the comparison for the smelter if its edges come back soft.
- Hyper3D Rodin: cited as the best at hard surface, the API and commercial licence behind a monthly business plan.
- TRELLIS.2: one shell with a baked look. Hunyuan3D: open weights whose licence excludes the EU.
- Blender MCP servers: an interactive viewport, nothing over the headless scripts the project already drives.
- CC0 kits (Kenney, Poly Haven): a cartoon low poly style or photoscans, neither the look; reference only.
