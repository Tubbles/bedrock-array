# 0015: The light demo from its scene file

Status: todo (2026-10-18)

Goal: the light demo's scene moves out of the Odin into `data/demos/light/scene.sjson`, read through 0014's parser, so the cave and surface scenes that follow are written as data on a demo that already works that way. The page looks exactly as before. Builds on 0014.

Verify:
- `./build.sh check`, `./build.sh test` (twenty one tests), `./build.sh web light`; the page shows the same scene as before (the user).

## Specification (main agent, 2026-10-18)

- `data/demos/light/scene.sjson`: the scene the demo hardcodes today: camera target [0, 0.5, 0], yaw 0.6, pitch 0.5, distance 5; sun direction [0.4, -1, -0.3], colour [1, 0.96, 0.9], intensity 1; exposure 1; items: a box size [1, 1, 1] at [0, 0.5, 0] in painted_steel, a cylinder radius 0.5, height 1, segments 24 at [1.5, 0.5, 0] in copper, a box size [6, 0.1, 6] at [0, -0.05, 0] in concrete; lights: [-1.5, 0.3, 1.5] colour [1, 0.6, 0.3] intensity 2 range 4 and [1, 0.3, -1.8] colour [0.3, 0.6, 1] intensity 2 range 4. A comment line at the top naming the demo.
- `src/engine/scene.odin`: `scene_item_mesh(item: Scene_Item) -> Mesh_Data` returns `box_mesh(item.size)` or `cylinder_mesh(item.radius, item.height, item.segments)` by shape. `src/engine/scene_test.odin`: `test_scene_item_mesh_by_shape` (a box item gives 24 vertices, a cylinder item with 8 segments gives 36).
- `src/demos/light/main.odin`: `scene` and `item_mesh_ids: []engine.Mesh_Id` as package globals; `main` loads `#load("../../../data/demos/light/scene.sjson")` through `engine.parse_scene(data, library)` after the library, prints the problem and returns when there is one, uploads one mesh per item through `scene_item_mesh` (freed after upload as today), and starts `orbit` from `scene.camera`. `step` builds the draw list from the scene: the camera from `orbit`, `scene.sun`, `scene.exposure`, every item at `linalg.matrix4_translate_f32(item.position)` with its material, every light. The hardcoded meshes, material ids, sun, exposure and lamps leave the file.
- `doc/build.md`, Writing a demo: one sentence that a demo's scene is `data/demos/<name>/scene.sjson`, loaded with `#load` and `parse_scene` (doc/render.md, Scene files, holds the format).

Verify: `./build.sh check` (silent), `./build.sh test` (twenty one tests), `./build.sh web light`.
