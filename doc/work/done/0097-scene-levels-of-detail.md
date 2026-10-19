# 0097: Levels of detail in a scene

Status: landed (2026-10-19, a0a0f12)

Goal: a scene item can list its levels of detail and the scene view draws the one 0096 chooses each frame.

Verify:
- `./build.sh test` with the new tests, `./build.sh check`, `./build.sh web models`, `./build.sh smoke`.

## Specification

- `src/engine/scene.odin`: `Scene_Item.levels: []string`, from the optional item key `levels` (mesh files, finest first, at least two), not together with `file` or `files` (an error naming both keys); an item with levels draws them in every configuration. `Scene.lod: Lod_Settings`, from an optional scene key `lod = {pixels_per_triangle, hysteresis, crossfade_seconds}` (each optional, the default for an absent one). Tests in `scene_test.odin`: `test_parse_scene_item_levels`, `test_parse_scene_lod_settings`.
- `src/engine/scene_view.odin`: `Scene_Item_Levels :: struct {mesh_ids: []Mesh_Id, triangle_counts: []int, half_extents: [3]f32, current: int}`, `Scene_View.item_levels: []Scene_Item_Levels` (one per item, empty for an item without levels), `Scene_View.lod: Lod_Settings` from the scene. The upload reads each level's blob (triangles from its index count), shares a blob file used twice as the configurations do, and keeps the finest level's half extents. `scene_view_choose_levels :: proc(view: ^Scene_View, canvas_height: f32)` sets each `current` through `lod_choose` from `lod_screen_pixels` of the sphere around the item's middle (`position + {0, half_extents.y * scale, 0}`, radius `length(half_extents) * scale`), nothing while `lod.freeze`. `scene_view_draw` calls it and draws the current level. Test `test_scene_view_choose_levels_by_distance` (a hand built view without GL: near picks the finest, far the coarsest, frozen keeps).
- `doc/render.md`: the scene keys paragraph names `levels` and `lod`.
