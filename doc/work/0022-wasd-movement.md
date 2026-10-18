# 0022: WASD movement

Status: todo (2026-10-18)

Goal: on the laptop the keys walk the orbit target: W and S along the camera's horizontal forward, A and D along its right, E and Q up and down, the arrow keys as WASD, at a speed that scales with the orbit distance so the walk feels the same zoomed in and out (user, 2026-10-18: "Let's do wasd for movement as well"). Builds on 0021.

Verify:
- `./build.sh check`, `./build.sh test` (twenty five tests), `./build.sh web cave`; holding W walks the cave past at a steady pace, the arrows do the same (the user).

## Specification (main agent, 2026-10-18)

Facts read 2026-10-18 from `~/opt/odin/core/sys/wasm/js/events.odin`: the kinds `.Key_Down` and `.Key_Up` with `e.data.key.code` (the physical key, `"KeyW"`, `"ArrowUp"`, ...) and `e.data.key.repeat`; `odin.js` calls `step(delta_time)` with seconds.

- `src/engine/render_camera.odin`: `orbit_walk :: proc(orbit: Orbit, input: [3]f32, metres: f32) -> Orbit`: `input.x` along the camera's right (as `orbit_pan` derives it), `input.y` along world up, `input.z` along the horizontal forward (the forward with y zeroed and normalised), the target moved by their sum times `metres`.
- `src/engine/render_test.odin`: `test_orbit_walk_moves_along_the_ground` (yaw 0, pitch 0.5, target at the origin: input `{0, 0, 1}` for 1 metre puts the target at z -1 within 1e-5 with y still 0; input `{1, 0, 0}` at x +1).
- `src/engine/web_scene_page.odin`: `scene_page_step(page: ^Scene_Page, delta_time: f32)`; the page keeps `keys_held: bit_set[Scene_Page_Key]` with `Scene_Page_Key :: enum { Forward, Back, Left, Right, Up, Down }`; window listeners for `.Key_Down` and `.Key_Up` map the codes (`KeyW`/`ArrowUp`, `KeyS`/`ArrowDown`, `KeyA`/`ArrowLeft`, `KeyD`/`ArrowRight`, `KeyE`, `KeyQ`) to the set, repeats ignored, unknown codes ignored. Each step with any key held walks by `orbit_walk(orbit, input, orbit.distance * SCENE_PAGE_WALK_SPEED * delta_time)` with `SCENE_PAGE_WALK_SPEED :: f32(0.6)` (orbit distances per second) and the input from the set (opposite keys cancel).
- `src/demos/light/main.odin` and `src/demos/cave/main.odin`: `step` passes `f32(delta_time)`.
- `doc/render.md`, Conventions: the orbit input sentence gains the keys.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty five tests), `./build.sh web cave`, `./build.sh web light`.
