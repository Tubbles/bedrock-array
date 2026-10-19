# 0096: The level of detail choice

Status: landed (2026-10-19, 626ce86)

Goal: the pure kernels that pick a model's level of detail from its size on screen, with a hysteresis band, the first piece of the LOD demo (user, 2026-10-19: "make all the items for the LOD demo"). Followed by 0097 to 0101.

Verify:
- `./build.sh test` with the new tests, `./build.sh check`.

## Specification

- New `src/engine/lod.odin` (no build tag): `Lod_Settings :: struct {pixels_per_triangle, hysteresis, crossfade_seconds: f32, freeze, tint: bool}` and `LOD_SETTINGS_DEFAULT :: Lod_Settings{pixels_per_triangle = 8, hysteresis = 0.15, crossfade_seconds = 0.4}`.
- `lod_wanted :: proc(triangle_counts: []int, screen_pixels, pixels_per_triangle: f32) -> int`: the counts are finest first and falling; the finest level whose `count * pixels_per_triangle <= screen_pixels`, the coarsest when none fits.
- `lod_choose :: proc(current: int, triangle_counts: []int, screen_pixels, pixels_per_triangle, hysteresis: f32) -> int`: finer than `current` only if `lod_wanted` of `screen_pixels * (1 - hysteresis)` is finer, coarser only if `lod_wanted` of `screen_pixels * (1 + hysteresis)` is coarser, else `current`. A `current` out of range is first clamped.
- `lod_screen_pixels :: proc(camera: Camera, canvas_height: f32, centre: [3]f32, radius: f32) -> f32`: the area in pixels of the bounding sphere's projected disc, its diameter `radius / (distance * tan(fov / 2)) * canvas_height`, the full canvas area squared when the camera is inside the sphere.
- New `src/engine/lod_test.odin` (`#+build !js`): `test_lod_wanted_picks_the_finest_that_fits`, `test_lod_wanted_falls_to_the_coarsest`, `test_lod_choose_holds_inside_the_band`, `test_lod_choose_switches_outside_the_band`, `test_lod_screen_pixels_halves_with_double_distance` (the area quarters).
- `doc/render.md`: a short paragraph on the level choice.
