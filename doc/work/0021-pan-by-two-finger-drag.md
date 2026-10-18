# 0021: Pan by two finger drag

Status: verified (2026-10-18)

Goal: two fingers moving together pan the orbit target across the view plane while their spread still zooms, and on the laptop the right mouse button drags the pan, so the camera reaches every corner of a scene instead of circling one point (user, 2026-10-18: "Can we get two finger drag to pan the camera around?"). Builds on 0016.

Verify:
- `./build.sh check`, `./build.sh test` (twenty four tests), `./build.sh web cave`; on the phone two fingers moved together slide the cave past, on the laptop the right button drags it and no context menu opens (the user).

## Specification (main agent, 2026-10-18)

Facts read 2026-10-18 from `~/opt/odin/core/sys/wasm/js/`: `e.data.mouse.buttons` is a `bit_set[0..<16; u16]` of the pressed buttons (bit 0 left, bit 1 right, bit 2 middle, as the DOM `buttons` mask); the event kind `.Context_Menu` exists and `js.event_prevent_default()` called inside a handler suppresses the browser's default action.

- `src/engine/render_camera.odin`: `orbit_pan :: proc(orbit: Orbit, delta_pixels: [2]f32, metres_per_pixel: f32) -> Orbit`: the camera's forward is the unit vector from its position to the target, right is `normalize(cross(forward, {0, 1, 0}))`, up is `cross(right, forward)`; the target moves by `-delta_pixels.x * metres_per_pixel` along right and `+delta_pixels.y * metres_per_pixel` along up (the world follows the fingers). `orbit_metres_per_pixel :: proc(orbit: Orbit, vertical_fov_radians: f32, canvas_height_pixels: f32) -> f32` returns `2 * distance * tan(fov / 2) / canvas_height_pixels`, the width of one pixel at the target's depth.
- `src/engine/render_test.odin`: `test_orbit_pan_moves_the_target_in_the_view_plane` (yaw 0, pitch 0, distance 5, target at the origin: a drag of `{10, 0}` at 0.1 metres per pixel moves the target to x -1, a drag of `{0, 10}` to y +1, within 1e-5) and `test_orbit_metres_per_pixel` (distance 5, fov `math.PI / 2`, height 1000 gives 0.01).
- `src/engine/web_scene_page.odin`: the page stores `client_height: f32` (CSS pixels, from `clientHeight` in the resize, since the pointer events are in CSS pixels). With two active pointers a move also pans by the midpoint delta (midpoint after minus before, from the stored client positions) through `orbit_pan` with `orbit_metres_per_pixel(orbit, math.PI / 3, client_height)`, besides the spread zoom. With one pointer whose `buttons` has bit 1 set, a move pans instead of turning. A `.Context_Menu` listener on the canvas calls `js.event_prevent_default()`.
- `doc/render.md`, Conventions: the orbit input sentence gains the pan (two fingers or the right button move the target in the view plane).

Verify: `./build.sh check` (silent), `./build.sh test` (twenty four tests), `./build.sh web cave`, `./build.sh web light`.
