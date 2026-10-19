# 0092: The orbit's focus steps through the items

Status: landed (2026-10-19, 98614db)

Goal: in orbit mode the orbit moves from one mesh item to the next and back, keeping its yaw, pitch and distance, so a detail zoomed in on one furnace can be compared on the next (user, 2026-10-19: "so i can toggle it around while zoomed in at various details").

Verify:
- `./build.sh test` with the new test, `./build.sh check`, `./build.sh web light`, `./build.sh smoke`.

## Specification

- `src/engine/scene_view.odin`: `Scene_Input.focus_step: int` (minus one, zero or one, an edge the caller detects); `Scene_View.focus: int`, the index into `view.scene.items` of the orbited item, at init the mesh item whose position is nearest the camera target (none: focus stays 0 and the target is the scene's). In orbit mode a nonzero `focus_step` moves `focus` to the next or previous item whose shape is `.Mesh`, wrapping, and sets `view.orbit.target` to that item's position plus the camera target's offset from the first focused item's position (kept in `Scene_View.focus_offset: [3]f32` at init), so the scene's camera target says where on the model the orbit looks. A pure procedure `scene_next_mesh_item :: proc(items: []Scene_Item, from, step: int) -> int` does the search. Fly mode ignores `focus_step`.
- Tests in `scene_view_test.odin`: `test_scene_next_mesh_item_skips_and_wraps` (a box, two meshes, a box: from mesh 1 forward gives mesh 2, from mesh 2 forward wraps to mesh 1, back from mesh 1 gives mesh 2), `test_scene_view_focus_step_moves_the_target` (a hand built view in orbit mode keeps distance and yaw and moves the target by the items' offset).
- `doc/render.md`: the orbit sentence of the camera paragraph names the focus.
