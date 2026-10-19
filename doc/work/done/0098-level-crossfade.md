# 0098: The dithered crossfade between levels

Status: landed (2026-10-19, a172362)

Goal: a level switch blends over `crossfade_seconds` by a dither instead of popping: the old and the new level draw complementary pixels.

Verify:
- `./build.sh test`, `./build.sh check`, `./build.sh web light`, `./build.sh smoke`.

## Specification

- `src/engine/render_draw_list.odin`: `Draw_Item.dither_skip: [2]f32`, a range of the dither threshold whose pixels the item discards; the zero value keeps every pixel.
- `src/engine/shaders/forward.frag`: `uniform vec2 dither_skip`; the threshold is a 4 by 4 ordered (Bayer) matrix at `gl_FragCoord.xy` scaled to 0..1; a fragment with `dither_skip.x <= threshold < dither_skip.y` is discarded first thing in `main`. `render_gl.odin` looks the uniform up and sets it per item.
- `src/engine/scene_view.odin`: `Scene_Item_Levels` gains `previous: int` and `fade: f32` (0 to 1, 1 meaning settled); a change of `current` in `scene_view_choose_levels` sets `previous` to the old level and `fade` to 0; `scene_view_step` advances `fade` by `delta_time / crossfade_seconds` (straight to 1 when the setting is 0). While fading, the draw adds the current level with `dither_skip = {fade, 1}` and the previous with `{0, fade}`. Test `test_scene_view_level_fade_advances_and_settles`.
- `doc/render.md`: the crossfade in the level paragraph.
