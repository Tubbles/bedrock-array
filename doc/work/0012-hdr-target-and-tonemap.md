# 0012: HDR target and tone mapping

Status: todo (2026-10-18)

Goal: the forward pass renders into a half float colour target and a second pass maps it to the canvas with an exposure and a filmic curve, so the sun can be brighter than white and the emissives of the bloom item have headroom. Replaces the gamma output of the forward shader. Builds on 0011.

Verify:
- `./build.sh check` validates four shaders, `./build.sh web light` builds; the page keeps its brightness at exposure 1 with the highlights rolled off instead of clipped (the user).

## Specification (main agent, 2026-10-18)

WebGL facts read from `~/opt/odin/vendor/wasm/WebGL/` on 2026-10-18: handles are `distinct u32` (`gl.Framebuffer(0)` is the canvas); `gl.GetExtension("EXT_color_buffer_float")` returns nothing and must be called once before a `RGBA16F` colour attachment renders; `gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, width, height, 0, gl.RGBA, gl.HALF_FLOAT, 0, nil)` allocates an empty texture; `gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, width, height)`; `gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE`; `gl.DrawArrays(gl.TRIANGLES, 0, 3)`; `gl.Uniform1i` for the sampler.

- `src/engine/shaders/tonemap.vert`: no attributes, a fullscreen triangle from `gl_VertexID` (positions (-1, -1), (3, -1), (-1, 3)), `out vec2 uv` = position * 0.5 + 0.5.
- `src/engine/shaders/tonemap.frag`: `uniform sampler2D scene; uniform float exposure;` colour = ACES fit of Narkowicz 2015 on `texture(scene, uv).rgb * exposure`: `(x (2.51 x + 0.03)) / (x (2.43 x + 0.59) + 0.14)` clamped to 0..1, then `pow(..., 1 / 2.2)`.
- `src/engine/shaders/forward.frag`: outputs the linear colour, no gamma.
- `src/engine/render_draw_list.odin`: `Draw_List` gains `exposure: f32`; `doc/render.md`, The draw list, names it.
- `src/engine/render_webgl.odin`: `Webgl_Target :: struct { framebuffer: gl.Framebuffer, colour: gl.Texture, depth: gl.Renderbuffer, width, height: i32 }` in `Webgl_Renderer` with `tonemap_program: gl.Program` and its two uniform locations. `webgl_renderer_init` compiles both programs and calls `GetExtension` once. `webgl_target_ensure(renderer, width, height)` (re)creates the target when the size differs, deleting the old handles: texture `NEAREST` filters and `CLAMP_TO_EDGE` wrap, depth renderbuffer, both attached. `webgl_renderer_draw`: ensure the target, bind it, viewport, clear, the forward pass as today, then bind `gl.Framebuffer(0)`, viewport, depth test off, the tonemap program with the colour texture on unit 0 and `list.exposure`, `DrawArrays` of three vertices with `BindVertexArray(0)`, depth test back on. When the target's status is not complete the draw returns after binding the canvas and clearing it.
- `src/demos/light/main.odin`: `draw_list.exposure = 1` beside the sun.
- `doc/render.md`, The WebGL2 renderer: the two passes, the target, the ACES fit, where exposure comes from, the gamma now at the end of the second pass.

Verify: `./build.sh check` (four shaders validated, silent), `./build.sh test` (sixteen tests), `./build.sh web light`.
