# 0010: Shader files and validation

Status: todo (2026-10-18)

Goal: the GLSL leaves the Odin string constants for files under `src/engine/shaders/`, and `./build.sh check` validates every shader with glslang, so a shader error surfaces in the check and not only in a browser console nobody in a session can read. No behaviour change on the page.

Verify:
- `./build.sh check` validates both shaders and exits 0; a deliberate typo in a shader makes it fail.
- `./build.sh web light` exits 0 and the page looks as before (the user).

## Specification (main agent, 2026-10-18)

- `src/engine/shaders/forward.vert` and `src/engine/shaders/forward.frag`: the two shader strings of `src/engine/render_webgl.odin` moved verbatim (`#version 300 es` first line, no trailing blank line). In `render_webgl.odin` the constants become `WEBGL_VERTEX_SHADER :: #load("shaders/forward.vert", string)` and `WEBGL_FRAGMENT_SHADER :: #load("shaders/forward.frag", string)`.
- `build.sh`, command `check`: after the Odin checks, a function `validate_shaders` runs `glslangValidator "$file"` for every `src/engine/shaders/*.vert` and `*.frag` (parse only, the stage from the extension) and fails the check on a non zero status. When `glslangValidator` is not on `PATH`, it prints `shader validation skipped: glslangValidator not found (brew install glslang)` to stderr and the check goes on.
- `doc/build.md`: the toolchain section names glslang (Homebrew `glslang`, optional, `glslangValidator`) and the check row names the shader validation. `doc/render.md`, The WebGL2 renderer: the shaders live in `src/engine/shaders/`, validated by the check.

Verify: `./build.sh check` (validation lines appear, exit 0), `./build.sh test` (sixteen tests), `./build.sh web light`.
