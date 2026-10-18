# 0023: Gamepad

Status: landed (2026-10-18, 8a69815)

Goal: a standard gamepad drives the page: the left stick walks, the right stick orbits, the triggers zoom, the d-pad moves up and down, with a dead zone so a resting stick drifts nothing (user, 2026-10-18: "and support gamepad"; CLAUDE.md: gamepad first, through the Gamepad API). Builds on 0022.

Verify:
- `./build.sh check`, `./build.sh test` (twenty six tests), `./build.sh web cave`; a pad connected to the laptop or the phone walks, turns and zooms the cave, and nothing drifts with the sticks at rest (the user).

## Specification (main agent, 2026-10-18)

Facts read 2026-10-18 from `~/opt/odin/core/sys/wasm/js/events.odin`: `js.get_gamepad_state(index, &state) -> bool` polls a pad (`Gamepad_State` with `connected`, `axes: [16]f64`, `buttons: [64]Gamepad_Button { value: f64, pressed, touched: bool }`); the window events `.Gamepad_Connected` and `.Gamepad_Disconnected` carry `e.data.gamepad.index`. The standard mapping (the Gamepad API): axes 0 and 1 the left stick, 2 and 3 the right stick (x right, y down), buttons 6 and 7 the left and right trigger with `value` 0 to 1, buttons 12 and 13 the d-pad up and down.

- `src/engine/render_camera.odin`: `stick_dead_zone :: proc(value, dead: f32) -> f32`: 0 inside the dead zone, else the remainder rescaled to 0..1 with the sign kept. `src/engine/render_test.odin`: `test_stick_dead_zone` (dead 0.15: 0.1 gives 0, 1 gives 1, 0.575 gives 0.5, -0.575 gives -0.5, within 1e-5).
- `src/engine/web_scene_page.odin`: the page keeps `gamepad_index: int` (starts at -1, set by the connected event, cleared by the disconnected one). Each step with an index at or above 0 polls the state and, when `connected`: the left stick walks with input `{x, 0, -y}` after the dead zone (`SCENE_PAGE_STICK_DEAD_ZONE :: f32(0.15)`) at the walk speed; the right stick turns through `orbit_drag` with `delta_pixels = {x, y} * SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND * delta_time` and 1 radian per pixel (`SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND :: f32(2)`); the triggers zoom through `orbit_zoom` with factor `1 - (right_trigger - left_trigger) * SCENE_PAGE_TRIGGER_ZOOM_PER_SECOND * delta_time` (`:: f32(0.8)`); d-pad up and down walk `{0, 1, 0}` and `{0, -1, 0}`.
- `doc/render.md`, Conventions: the orbit input sentence gains the pad.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty six tests), `./build.sh web cave`, `./build.sh web light`.
