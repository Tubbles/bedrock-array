# 0017: Ambient in the scene file

Status: todo (2026-10-18)

Goal: the ambient term leaves the renderer constant and comes from the scene, so a cave can be dark and a surface scene bright before the sky ambient of stage 1 replaces the number with a model. Builds on 0016.

Verify:
- `./build.sh check`, `./build.sh test` (twenty two tests), `./build.sh web light`; the light page looks as before with `ambient = 0.15` in its scene (the user).

## Specification (main agent, 2026-10-18)

- `src/engine/render_draw_list.odin`: `Draw_List` gains `ambient: f32` after `exposure`, a one line comment (the fraction of the albedo lit from everywhere, until the sky ambient).
- `src/engine/render_webgl.odin`: `WEBGL_AMBIENT` removed, the uniform set from `list.ambient`.
- `src/engine/scene.odin`: `Scene` gains `ambient: f32`, read from an optional root key `ambient` (at least 0, default 0.15 when absent). `src/engine/scene_test.odin`: `test_parse_scene_ambient_default_and_value` (absent gives 0.15, `ambient = 0.02` gives 0.02).
- `src/engine/web_scene_page.odin`: the draw list takes `scene.ambient`.
- `data/demos/light/scene.sjson`: `ambient = 0.15` after `exposure`.
- `doc/render.md`: the draw list sentence names ambient; Scene files names the optional key and its default; the WebGL2 renderer section drops the constant.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty two tests), `./build.sh web light`.
