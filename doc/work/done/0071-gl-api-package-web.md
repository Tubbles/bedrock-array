# 0071: The GL api package, the web side

Status: landed (2026-10-19, 8824403)

Goal: the renderer compiles for the browser and natively from one source. WebGL2 and OpenGL 3.3 core are the same API family, and the two Odin bindings differ in handle types and a dozen signatures, so a package `glapi` under the engine gives the renderer one name set with a file per target. This item is the web side: the renderer imports the package and nothing changes on the pages.

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh web light`, `web cave`, `web surface` and `web models` pass; the installed pages look as before.
- `grep -n "vendor:wasm/WebGL" src/engine/render_webgl.odin` finds nothing.

## Specification

- `src/engine/glapi/api_web.odin` (`#+build js wasm32`, package `glapi`): `import webgl "vendor:wasm/WebGL"`, then one alias per identifier the renderer uses, in three groups: the types `Enum`, `Buffer`, `Texture`, `Program`, `Framebuffer`, `Renderbuffer`, `VertexArrayObject`; the procedures `ActiveTexture`, `BindBuffer`, `BindFramebuffer`, `BindRenderbuffer`, `BindTexture`, `BindVertexArray`, `BlendFunc`, `BufferDataSlice`, `CheckFramebufferStatus`, `Clear`, `ClearColor`, `CreateBuffer`, `CreateFramebuffer`, `CreateProgramFromStrings`, `CreateRenderbuffer`, `CreateTexture`, `CreateVertexArray`, `DeleteFramebuffer`, `DeleteRenderbuffer`, `DeleteTexture`, `DepthFunc`, `Disable`, `DrawArrays`, `DrawElements`, `Enable`, `EnableVertexAttribArray`, `FramebufferRenderbuffer`, `FramebufferTexture2D`, `FrontFace`, `GenerateMipmap`, `GetExtension`, `GetUniformLocation`, `PixelStorei`, `RenderbufferStorage`, `TexImage2D`, `TexImage2DSlice`, `TexParameteri`, `Uniform1f`, `Uniform1fv`, `Uniform1i`, `Uniform2f`, `Uniform3f`, `Uniform3fv`, `UniformMatrix4fv`, `UseProgram`, `VertexAttribPointer`, `Viewport`; the constants `ARRAY_BUFFER`, `BLEND`, `CCW`, `CLAMP_TO_EDGE`, `COLOR_ATTACHMENT0`, `COLOR_BUFFER_BIT`, `CULL_FACE`, `DEPTH_ATTACHMENT`, `DEPTH_BUFFER_BIT`, `DEPTH_COMPONENT24`, `DEPTH_TEST`, `ELEMENT_ARRAY_BUFFER`, `FLOAT`, `FRAMEBUFFER`, `FRAMEBUFFER_COMPLETE`, `HALF_FLOAT`, `LEQUAL`, `LINEAR`, `LINEAR_MIPMAP_LINEAR`, `NEAREST`, `ONE`, `RENDERBUFFER`, `REPEAT`, `RGBA`, `RGBA16F`, `RGBA8`, `SRGB8_ALPHA8`, `STATIC_DRAW`, `TEXTURE0`, `TEXTURE1`, `TEXTURE_2D`, `TEXTURE_MAG_FILTER`, `TEXTURE_MIN_FILTER`, `TEXTURE_WRAP_S`, `TEXTURE_WRAP_T`, `TRIANGLES`, `UNPACK_FLIP_Y_WEBGL`, `UNSIGNED_BYTE`, `UNSIGNED_INT`. Each line `Name :: webgl.Name`. A header comment says the package exists so one renderer compiles for both targets and that the native file comes with item 0072.
- `src/engine/render_webgl.odin`: the import becomes `import gl "glapi"`; nothing else changes.
- `doc/render.md`, the renderer paragraph: one clause naming `src/engine/glapi/` as the binding the renderer draws through, one file per target.
