# 0067: The fly camera

Status: landed (2026-10-19, 1301e12)

Goal: a first person camera for the pages (user, 2026-10-19: the mouse turns the view as it moves, WASD walks, no zoom, no drag): a position with a yaw and a pitch, pure, beside the orbit, which stays the scene's start.

Verify:
- `./build.sh test` passes with `test_fly_from_orbit_looks_at_the_target` (the fly made from an orbit stands at the orbit camera's position and its camera's target lies one metre along the line to the orbit's target, within 1e-4), `test_fly_turn_turns_and_clamps` (a move to the right lowers the yaw, a move down raises the pitch, the pitch stops at `ORBIT_PITCH_LIMIT`) and `test_fly_walk_moves_along_the_ground_and_up` (from a fly at yaw 0 and pitch 0.5 an input of z 1 moves the position along minus z only, x 1 along plus x, y 1 along plus y).
- `./build.sh check` passes.

## Specification

- `src/engine/render_camera.odin`, after `orbit_fit_width`: `Fly :: struct { position: [3]f32, yaw, pitch: f32 }`, the doc comment saying it looks the opposite way of the orbit's offset, so an orbit's yaw and pitch carry over and a positive pitch looks down. `fly_forward(yaw, pitch: f32) -> [3]f32` (`@(private = "file")`): minus the orbit's direction, `-{cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)}`. `fly_from_orbit(orbit: Orbit) -> Fly`: the position of `orbit_camera(orbit, 0, 0, 0)` with the orbit's yaw and pitch. `fly_camera(fly: Fly, vertical_fov_radians, near, far: f32) -> Camera`: the position, the target one metre along the forward, up `{0, 1, 0}`. `fly_turn(fly: Fly, delta_pixels: [2]f32, radians_per_pixel: f32) -> Fly`: right lowers the yaw, down raises the pitch, the pitch clamped to plus or minus `ORBIT_PITCH_LIMIT`, as `orbit_drag` does. `fly_walk(fly: Fly, input: [3]f32, metres: f32) -> Fly`: the position moved by `input.x` along the right (`cross(forward_horizontal, {0, 1, 0})`), `input.y` along world up and `input.z` along the horizontal forward (the forward with y zeroed, normalised), times metres, as `orbit_walk` does for the target.
- `src/engine/render_test.odin`: the three tests, after `test_orbit_fit_width`.
- `doc/render.md`, the camera paragraph: one sentence after the `orbit_camera` sentence: `Fly` is the first person camera, made from an orbit by `fly_from_orbit` and turned and walked by `fly_turn` and `fly_walk`, its camera from `fly_camera`.
