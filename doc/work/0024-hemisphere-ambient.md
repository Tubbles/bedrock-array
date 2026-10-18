# 0024: Hemisphere ambient

Status: todo (2026-10-18)

Goal: the flat ambient becomes a hemisphere: a sky colour from above and a ground colour from below, blended by the normal's height, so a surface scene reads as lit by a sky and the undersides of things go dark. The first half of stage 1's sky ambient; the sky model that feeds the colours comes with the day and weather work. A scene without the keys looks as before. Builds on 0019.

Verify:
- `./build.sh check`, `./build.sh test` (twenty seven tests), `./build.sh web light`; the light page is unchanged, and a scene with a blue sky and a brown ground colour lights the top of the box blue and its underside brown (the user, on the surface page of 0025).

## Specification (main agent, 2026-10-18)

- `src/engine/scene.odin`: `Scene` gains `sky_colour, ground_colour: [3]f32`, optional root keys `sky_colour` and `ground_colour` (three numbers, 0 or more); when absent both default to `ambient` times white, so `ambient` keeps its meaning as the flat level and is the fallback. `src/engine/scene_test.odin`: `test_parse_scene_hemisphere_defaults_to_ambient` (absent keys give `{0.15, 0.15, 0.15}` for both at the default ambient; `sky_colour = [0.2, 0.3, 0.5]` is read).
- `src/engine/render_draw_list.odin`: `Draw_List` gains `sky_colour, ground_colour: [3]f32` beside `ambient`; `src/engine/web_scene_page.odin` sets them from the scene.
- `src/engine/shaders/forward.frag`: the `ambient` uniform becomes `uniform vec3 sky_colour; uniform vec3 ground_colour;` and the ambient term is `mix(ground_colour, sky_colour, n.y * 0.5 + 0.5) * albedo`; `src/engine/render_webgl.odin` fetches and sets the two uniforms in place of `ambient`.
- `doc/render.md`: the draw list sentence, the Scene files keys and the renderer section follow.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty seven tests), `./build.sh web light`, `./build.sh web cave`.
