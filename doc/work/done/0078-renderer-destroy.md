# 0078: The renderer frees its GL objects

Status: landed (2026-10-19, 7335284)

Goal: `scene_view_destroy` frees everything `scene_view_init` made, the GL objects included, so the menu's enter and leave (0076) no longer leaks a renderer per round trip (the 0076 review measured about 65 MB per trip on llvmpipe). Follows 0073 and 0076.

Verify:
- `./build.sh check`, `test`, `smoke` pass; `./build.sh web light` and `web models` build.
- The 0076 review's loop probe (nine menu to models round trips, the resident size printed per trip) no longer grows trip over trip.

## Specification

- `src/engine/glapi/api_web.odin`: `DeleteBuffer :: webgl.DeleteBuffer`, `DeleteVertexArray :: webgl.DeleteVertexArray`, `DeleteProgram :: webgl.DeleteProgram`, in their groups.
- `src/engine/glapi/api_native.odin`: the same three with the WebGL signatures over `gl.DeleteBuffers(1, &handle)`, `gl.DeleteVertexArrays(1, &handle)`, `gl.DeleteProgram(handle)`, beside the existing `Delete*` wrappers.
- `src/engine/render_gl.odin`: `gl_renderer_target_destroy(target: ^Gl_Target)` lifted out of `gl_renderer_target_ensure` (the colour texture, the depth renderbuffer when there is one, the framebuffer, the target zeroed), used there and by the new `gl_renderer_destroy(renderer: ^Gl_Renderer)`: the four programs, every mesh's vertex array and two buffers, every present texture set's three textures, the target and the bloom targets, the fullscreen vertex array, then the two dynamic arrays freed and the renderer zeroed.
- `src/engine/scene_view.odin`: `scene_view_destroy` calls `gl_renderer_destroy` first, its comment updated.
- `doc/render.md`: the sentence on the renderer's objects says `gl_renderer_destroy` frees them and `scene_view_destroy` calls it.
