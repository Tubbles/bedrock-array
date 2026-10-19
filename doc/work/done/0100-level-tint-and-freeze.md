# 0100: Level tint and freeze

Status: landed (2026-10-19, 70d4e1d)

Goal: two debug switches for judging the levels: a tint per level and a freeze that holds every item's level while walking up to it.

Verify:
- `./build.sh test`, `./build.sh check`, `./build.sh debug`, `./build.sh smoke`.

## Specification

- `src/engine/render_draw_list.odin`: `Draw_Item.tint: [3]f32`, multiplied into the albedo by the renderer, set to `{1, 1, 1}` by `draw_list_add`; `render_gl.odin` and `forward.frag` (`uniform vec3 tint`).
- `src/engine/lod.odin`: `lod_tint :: proc(level: int) -> [3]f32`, a fixed palette of eight distinct colours, the last for every level past it. Test `test_lod_tint_is_distinct_per_level`.
- `src/engine/scene_view.odin`: with `lod.tint` the draw tints each level item by its current level.
- `src/app/main.odin`: in a demo, T toggles `view.lod.tint` and F `view.lod.freeze`. `doc/build.md` names the keys.
