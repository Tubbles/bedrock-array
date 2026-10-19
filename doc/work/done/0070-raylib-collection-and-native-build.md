# 0070: The raylib collection and the native build

Status: landed (2026-10-19, d73cd42)

Goal: the first native binary (user, 2026-10-19: the tech demos on the TV through Steam, the gamepad for everything). This item is the ground: the raylib 6.0 collection carried from Mine oh Belowed, `build.sh debug` and `release` building `src/app/` to `build/bedrock-array`, and a window that opens, draws the build stamp and closes, run headless here through Xvfb so a link or a window problem shows in this session and not on the couch.

Verify:
- `./build.sh debug` and `./build.sh release` write `build/bedrock-array`; `./build.sh check` passes (it now checks `src/app` natively too); `./build.sh test` passes.
- `./build.sh smoke` runs the binary under `xvfb-run` for three frames and exits 0, printing the GL vendor, renderer and version lines.

## Specification

- `shared/raylib/`: carried by the main agent before the item runs: `raylib.odin`, `raymath.odin`, `rlgl/rlgl.odin` and `LICENSE` from the toolchain's `vendor/raylib/` (raylib 6.0), `linux/libraylib.a` from Mine oh Belowed (GLFW with Wayland and X11), `platform.odin` (ours: `glfwGetPlatform`, `glfwGetCurrentContext`, `glfwGetWindowSize`, `glfwGetProcAddress` declared from the same archive, Linux only), `README.md` with the why and the build record, `tools/build_raylib.sh` (desktop only).
- `build.sh`: `debug` and `release` run `odin build src/app -out:build/bedrock-array -collection:shared=shared -vet -strict-style -define:BUILD_INFO=...` with `-debug` or `-o:speed`, plus `-extra-linker-flags:"-L tmp/linker-shims"` after creating the shims `libX11.so` and `libSDL3.so` as symlinks to `/usr/lib64/libX11.so.6` and `/usr/lib64/libSDL3.so.0` (Bazzite ships no unversioned development links); `check` gains `odin check src/app` with the collection; `smoke` runs `xvfb-run -a -s "-screen 0 1280x720x24" env XDG_SESSION_TYPE=x11 build/bedrock-array --frames 3` after a debug build; the usage text and `doc/build.md` name the three.
- `src/app/main.odin`, package `app`: `BUILD_INFO :: #config(BUILD_INFO, "dev")`; `main` parses `--frames <n>` (0 means until the window closes) and `--windowed` (otherwise the window goes borderless over the monitor after opening, `rl.ToggleBorderlessWindowed`), sets `rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .VSYNC_HINT})`, `rl.SetTraceLogLevel(.WARNING)`, opens `rl.InitWindow(1280, 720, "Bedrock Array")`, exits 1 with a line on stderr when `rl.IsWindowReady` is false, sets `rl.SetExitKey(.KEY_NULL)`, prints the GL vendor, renderer and version read through `rl.glfwGetProcAddress("glGetString")` as Mine oh Belowed's `log_gl_info` does, then loops `rl.WindowShouldClose` or the frame count: `rl.BeginDrawing`, `rl.ClearBackground` a dark grey, `rl.DrawText` of "Bedrock Array" and the build stamp, `rl.EndDrawing`; `rl.CloseWindow` at the end. No other behaviour.
- `doc/build.md`: the native commands, the collection and the shims in the style of the web section; `CLAUDE.md`'s stack line for phase B stays true.
