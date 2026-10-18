# 0013: Point lights

Status: verified (2026-10-18)

Goal: the draw list carries point lights and the forward shader adds up to eight of them with a windowed inverse square falloff, so the light demo can show two lamps beside the sun and the cave scene has its first light source. The CPU clustering of stage 1 comes when a scene needs more than eight. Builds on 0012.

Verify:
- `./build.sh check`, `./build.sh test` (seventeen tests), `./build.sh web light`; on the page two coloured lamps light the shapes from low angles and fade out at their range (the user).

## Specification (main agent, 2026-10-18)

Binding facts read 2026-10-18: `gl.Uniform3fv(location, v: []glm.vec3)` and `gl.Uniform1fv(location, v: []f32)` set consecutive array elements from the location of element 0 (`glm.vec3` is `[3]f32`); `gl.Uniform1i` sets an `int`.

- `src/engine/render_draw_list.odin`: `Point_Light :: struct { position, colour: [3]f32, intensity, range: f32 }` (intensity as for the sun: what a white Lambert surface one metre away, facing it, returns; range where the light reaches zero). `Draw_List` gains `lights: [dynamic]Point_Light`; `draw_list_add_light(list: ^Draw_List, light: Point_Light)`; `draw_list_clear` clears the lights too, `draw_list_destroy` frees them. `WEBGL_MAX_POINT_LIGHTS :: 8` in `render_webgl.odin`, the shader's constant matches.
- `src/engine/render_test.odin`: `test_draw_list_lights_add_and_clear` (two lights added, count two, clear empties both items and lights).
- `src/engine/shaders/forward.frag`: `const int MAX_POINT_LIGHTS = 8; uniform int point_light_count; uniform vec3 point_light_position[MAX_POINT_LIGHTS]; uniform vec3 point_light_colour[MAX_POINT_LIGHTS]; uniform float point_light_range[MAX_POINT_LIGHTS];` (colour carries the intensity). The BRDF moves into `vec3 shade(vec3 n, vec3 v, vec3 l, vec3 radiance)` returning `(diffuse + specular) * radiance * n_dot_l`, the sun calls it with `sun_colour * PI`; a loop over the lights computes `to_light = position - world_position`, `distance`, `l = to_light / distance`, `window = clamp(1.0 - pow(distance / range, 4.0), 0.0, 1.0)`, `attenuation = window * window / max(distance * distance, 0.01)` (the distance floored at 0.0001 and the range at 0.001 on upload, so a light on a surface or a zero range stays finite), and adds `shade(n, v, l, colour * PI * attenuation)`. Ambient and emissive as before.
- `src/engine/render_webgl.odin`: `Webgl_Uniforms` gains the four locations; `webgl_renderer_draw` uploads `min(len(list.lights), WEBGL_MAX_POINT_LIGHTS)` lights into three fixed arrays (`[WEBGL_MAX_POINT_LIGHTS][3]f32` positions, premultiplied colours, `[WEBGL_MAX_POINT_LIGHTS]f32` ranges) and sets the count, once per draw.
- `src/demos/light/main.odin`: two lamps each frame: `{position = {-1.5, 0.3, 1.5}, colour = {1.0, 0.6, 0.3}, intensity = 2, range = 4}` and `{position = {1.0, 0.3, -1.8}, colour = {0.3, 0.6, 1.0}, intensity = 2, range = 4}`.
- `doc/render.md`: The draw list names the lights and the intensity meaning; The WebGL2 renderer names the eight light limit and the falloff.

Verify: `./build.sh check` (silent), `./build.sh test` (seventeen tests), `./build.sh web light`.
