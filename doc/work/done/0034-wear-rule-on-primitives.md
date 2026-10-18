# 0034: The wear rule on primitives

Status: landed (2026-10-18, 03be8ac)

Goal: the chipped paint of `doc/workflows/materials.md`: the renderer cuts the baked wear field against the fragment's distance to its primitive's edges, and a chip shows the bare metal, its roughness and its metallic reflection, so the machine block of the surface page wears at its edges. Refers to items 0028, 0031 and 0033.

Verify:
- `./build.sh test` passes with the new test, `./build.sh check`, `./build.sh web surface`; the block's edges show chips of bare metal fading over about five centimetres, the faces a few, the user's judgement.

## Specification (main agent, 2026-10-18)

Binding facts, read 2026-10-18: `Draw_Item` is `{ mesh, material, transform }` and `draw_list_add(list, mesh, material, transform)` is called by `web_scene_page.odin` line 89 and `render_test.odin` lines 189, 190 and 200; `Scene_Item` has `shape`, `size`, `radius`, `height`; `box_mesh(size)` centres the box on the origin with half extents `size / 2`, so the vertex `position` is the local position; `forward.vert` passes `world_normal` and `world_position`. The rule: `wear = step(chip_threshold, field + amount * (1 - smoothstep(0, edge_width, edge)))`, with `edge` the distance to the nearest edge of the box, which on a face is the second smallest of the three face distances `half_extents - abs(local_position)`: `max(max(min(d.x, d.y), min(d.x, d.z)), min(d.y, d.z))`.

- `src/engine/render_draw_list.odin`: `Draw_Item.half_extents: [3]f32`; `draw_list_add` gains `half_extents: [3]f32` as its last parameter; the three test calls pass `{1, 1, 1}`.
- `src/engine/scene.odin`: `scene_item_half_extents(item: Scene_Item) -> [3]f32`, pure: `size / 2` for a box and a room, `{radius, height / 2, radius}` for a cylinder. `web_scene_page.odin` line 89 passes it. `src/engine/scene_test.odin`: `test_scene_item_half_extents` (a box of size `{2, 4, 6}` gives `{1, 2, 3}`, a cylinder of radius 0.5 and height 2 gives `{0.5, 1, 0.5}`).
- `src/engine/shaders/forward.vert`: `out vec3 local_position;` set to `position`.
- `src/engine/shaders/forward.frag`: `in vec3 local_position;`, uniforms `vec3 half_extents`, `float wear_edge_width`, `float wear_chip_threshold`, `float wear_amount`, `vec3 wear_metal`; `edge_distance()` as above; `wear_at(field)` the rule; in `surface_at`, when textured, with `field` the surface map's `b` at the two scales and `wear = wear_at(field)`: albedo `mix(albedo * map, wear_metal, wear)`, roughness `mix(surface.r, surface.g, wear)`, metallic `mix(metallic, 1.0, wear)`. Untextured materials are unchanged.
- `src/engine/render_webgl.odin`: `Webgl_Uniforms` gains `half_extents, wear_edge_width, wear_chip_threshold, wear_amount, wear_metal: i32`, fetched at init, set per item in the draw loop from `item.half_extents` and `material.wear` (a file private `webgl_upload_wear(uniforms, item, material)`).
- `doc/render.md`, The WebGL2 renderer: one sentence that the forward pass applies the wear rule of `doc/workflows/materials.md` from the local position and the item's half extents, with the edge distance formula.

Verify: `./build.sh check`, `./build.sh test`, `./build.sh web surface`.

Decision at the fix round, 2026-10-18: a preset naming a texture set without a `wear` block would upload zeros and read as bare metal everywhere, so the parser rejects it (`textures without wear`), and the step is a strict greater than so `chip_threshold = 1` with `amount = 0` means no chips.
