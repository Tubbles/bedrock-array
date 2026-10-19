# 0072: The GL api package, the native side, and the renderer for both targets

Status: landed (2026-10-19, 5dae33d)

Goal: the renderer compiles natively over `vendor:OpenGL` through the same names, the shaders run under a desktop version line, and the file that was the WebGL renderer becomes the GL renderer of both targets.

Verify:
- `./build.sh check` passes with `src/engine` checked natively, so `render_gl.odin` and `glapi/api_native.odin` compile; `./build.sh test` passes; `./build.sh web light` and `web models` build and the pages look as before.
- `./build.sh check`'s shader validation passes for both version lines (glslangValidator, installed through brew).
- `grep -rn "webgl_\|Webgl_\|render_webgl" src doc web` finds nothing outside doc/work and doc/log.

## Specification

- `src/engine/glapi/api_native.odin` (`#+build !js`, package `glapi`): `import gl "vendor:OpenGL"`; the same identifiers as `api_web.odin`, each with the WebGL binding's signature: a plain alias where the desktop binding's signature matches once the types alias (`Enum :: u32`, the six handle types `u32`), and a small wrapper where it does not, read off the two bindings (`~/opt/odin/vendor/wasm/WebGL/webgl.odin`, `webgl2.odin`, `webgl_helpers.odin` against `~/opt/odin/vendor/OpenGL/wrappers.odin` and `helpers.odin`): the five `Create*` through `Gen*` of one, the three `Delete*` through `Delete*s` of one, `BufferDataSlice` and `TexImage2DSlice` from the slice's bytes, `TexImage2D` with the WebGL parameter list, `GetUniformLocation` taking a string (a temp cstring), `Uniform1fv`, `Uniform3fv` and `UniformMatrix4fv` with the WebGL parameter lists (`UniformMatrix4fv(location, m)` passing one matrix untransposed), `VertexAttribPointer` and `DrawElements` with the WebGL parameter lists, `CreateProgramFromStrings(vs_sources, fs_sources: []string) -> (Program, bool)` concatenating each list, replacing a leading `#version 300 es` line by `#version 330 core` (`shader_source_for_desktop`, pure, in this file, tested), and linking through `gl.load_shaders_source`, with the info log on stderr when it fails; `GetExtension` doing nothing (half float colour attachments are core in 3.3); `UNPACK_FLIP_Y_WEBGL` a constant of the package and `PixelStorei` keeping a file level `flip_y: bool` for it (any other name goes to `gl.PixelStorei`), which `TexImage2DSlice` honours by uploading the rows in reverse order through a temp copy.
- `src/engine/glapi/api_native_test.odin` (`#+build !js`): `test_shader_source_for_desktop` (the version line swapped, the rest byte for byte, a source without the line unchanged).
- `src/engine/render_webgl.odin` becomes `src/engine/render_gl.odin` (a plain `mv`, the main agent stages the rename), the build tag dropped, `Webgl_` types renamed `Gl_` and `webgl_` procedures `gl_renderer_` (`webgl_renderer_init` to `gl_renderer_init`, `webgl_upload_image` to `gl_renderer_upload_image` and so on), the callers in `src/engine/web_scene_page.odin` and the sentences in `doc/render.md` following, the build tag note in `doc/render.md` and `CLAUDE.md`'s layout line (web only files carry the tag: the renderer no longer is one) corrected.
- `build.sh`, `validate_shaders`: each shader is validated as it is and once more as a temp copy whose first line is `#version 330 core`, so the desktop profile is covered.
