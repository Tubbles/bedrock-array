# 0008: The light demo page

Status: todo (2026-10-18)

Goal: the light demo of 0007 gains its interaction: the orbit camera driven by pointer drag (touch and mouse), the wheel and a two finger pinch, with the orbit arithmetic in the engine where it is tested. The demo never reaches into the renderer. The first page of D1 that the user judges.

Verify:
- `./build.sh web light` builds, the page orbits by touch and by mouse on the phone and the laptop (the user).

## Specification (main agent, 2026-10-18)

Builds on 0007. Event facts read from `~/opt/odin/core/sys/wasm/js/events.odin` on 2026-10-18: the kinds `Pointer_Down`, `Pointer_Move`, `Pointer_Up`, `Pointer_Cancel` and `Wheel`; in the `Event` the pointer data sits under `e.data.mouse` (`client: [2]i64`, `movement: [2]i64`, `buttons`) with `e.data.mouse.pointer.pointer_id: int` and `is_primary: bool`; the wheel delta is `e.data.wheel.delta: [3]f64`.

- `src/engine/render_camera.odin`: two pure procedures. `orbit_drag :: proc(orbit: Orbit, delta_pixels: [2]f32, radians_per_pixel: f32) -> Orbit`: yaw decreases by `delta_pixels.x * radians_per_pixel`, pitch increases by `delta_pixels.y * radians_per_pixel`, pitch clamped to plus or minus `ORBIT_PITCH_LIMIT :: 1.5` radians. `orbit_zoom :: proc(orbit: Orbit, factor: f32, minimum, maximum: f32) -> Orbit`: distance multiplied by `factor` and clamped to the range.
- `src/engine/render_test.odin`: `test_orbit_drag_turns_and_clamps` (a drag of `{100, 0}` at 0.01 radians per pixel lowers yaw by 1; a drag of `{0, 1000}` pins pitch at the limit) and `test_orbit_zoom_scales_and_clamps` (factor 2 doubles the distance, a factor that would pass the maximum stops at it).
- `src/demos/light/main.odin`: the orbit becomes a package global starting at the values 0007 used. Pointers: a small table of up to two active pointers (`pointer_id`, `client` position), filled on `Pointer_Down`, updated on `Pointer_Move`, cleared on `Pointer_Up` and `Pointer_Cancel`. With one active pointer a move drags the orbit by `movement` at `DRAG_RADIANS_PER_PIXEL :: 0.005`. With two, a move zooms by the ratio of the new to the old distance between the two client positions, inverted (fingers apart means closer), distance clamped to 2 and 20. `Wheel`: a positive `delta.y` zooms out by `WHEEL_ZOOM_STEP :: 1.1`, a negative one in by its inverse. Listeners on the canvas, the wheel listener too. `step` builds the camera from the global orbit each frame as before.
- `doc/render.md`, Conventions: one sentence on the orbit input: drag turns, pinch and wheel zoom, pitch limited short of the poles.

Verify: `./build.sh check`, `./build.sh test` (eleven tests), `./build.sh web light`; the page orbits by one finger and by mouse drag, zooms by pinch and by wheel, on the phone and the laptop (the user).

