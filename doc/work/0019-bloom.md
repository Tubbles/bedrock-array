# 0019: Bloom

Status: todo (2026-10-18)

Goal: the emissive flora of the cave glows beyond its surface: a bright pass at half resolution, a separable Gaussian blur, and the blurred light added before the tone map. Threshold and strength are renderer constants here and move into the scene file in a later item. Builds on 0018.

Verify:
- `./build.sh check` validates six shaders, `./build.sh web cave`; the moss and fungus of the cave page bloom softly, the light page is unchanged but for a faint glow on the copper highlight (the user).

## Specification (main agent, 2026-10-18)

- `src/engine/shaders/bright.frag` (`tonemap.vert` serves every fullscreen pass): `uniform sampler2D scene; uniform float threshold;` outputs `max(texture(scene, uv).rgb - threshold, 0.0)`.
- `src/engine/shaders/blur.frag`: `uniform sampler2D source; uniform vec2 step;` (one texel along the blur axis) a nine tap Gaussian: weights 0.227027 at the centre, 0.1945946, 0.1216216, 0.054054, 0.016216 at one to four texels either side.
- `src/engine/shaders/tonemap.frag`: `uniform sampler2D bloom; uniform float bloom_strength;` adds `texture(bloom, uv).rgb * bloom_strength` to the scene colour before the exposure and the curve.
- `src/engine/render_webgl.odin`: `webgl_target_ensure` takes the target (`target: ^Webgl_Target, width, height: i32, with_depth, linear: bool`), the depth renderbuffer only `with_depth`, `LINEAR` filters when `linear`; `Webgl_Renderer` gains `bloom_targets: [2]Webgl_Target` (half the canvas size, no depth, linear), `bright_program`, `blur_program` and their uniform locations (`scene`, `threshold`; `source`, `step`), the tonemap uniforms gain `bloom` and `bloom_strength`; constants `WEBGL_BLOOM_THRESHOLD :: f32(1)` and `WEBGL_BLOOM_STRENGTH :: f32(0.08)`. A helper `webgl_draw_fullscreen(target: gl.Framebuffer, width, height: i32)` binds, sets the viewport and draws the three vertices with the depth test off. The draw after the forward pass: bright from the scene colour into `bloom_targets[0]`, blur with step `(2 / width, 0)` (texels of the half size target: `1 / half_width`) from 0 into 1, blur with the vertical step from 1 into 0, then the tonemap with the scene colour on unit 0 and `bloom_targets[0]` on unit 1. Both textures unbound after.
- `doc/render.md`, The WebGL2 renderer: the bloom passes, the half size targets, the constants.

Verify: `./build.sh check` (silent, six shaders), `./build.sh test` (twenty two tests), `./build.sh web cave`, `./build.sh web light`.
