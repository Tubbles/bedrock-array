# 0062: The start distance on a narrow canvas

Status: landed (2026-10-19, 9cd0532)

Goal: a scene's camera distance is written for a landscape canvas, and on a phone in portrait the same distance cuts the models page's row off at both sides (item 0061's review). A scene can name the width its start view must show, and the page moves the camera back on a canvas too narrow for it, from where the user zooms in.

Verify:
- `./build.sh test` passes with `test_parse_scene_reads_fit_width` (a camera with `fit_width = 10` parses to it, absent gives 0, a negative one is rejected) and `test_orbit_fit_width` (a width of 10 at a field of view of 60 degrees on an aspect of 0.5 raises a distance of 7.5 to 10 times the square root of 3, about 17.32, a wide aspect leaves 7.5, the result never above the maximum, a width of 0 leaves the orbit).
- `./build.sh check` passes, `./build.sh web models` builds.

## Specification

- `src/engine/scene.odin`: `Scene` gains `fit_width: f32`, read by `parse_scene_camera` from the camera object's optional `fit_width` (`scene_non_negative_field`, 0 when absent, the key added to the camera's known keys), returned beside the `Orbit`.
- `src/engine/render_camera.odin`: `orbit_fit_width(orbit: Orbit, fit_width, vertical_fov_radians, aspect, maximum_distance: f32) -> Orbit`, pure: the distance raised to the least that shows `fit_width` across the canvas at the target's depth, `fit_width / (2 * tan(vertical_fov_radians / 2) * aspect)`, never lowered, limited to the maximum, the orbit unchanged for a width of 0.
- `src/engine/scene_test.odin` and `src/engine/render_test.odin`: the two tests above, beside the camera and orbit tests that exist.
- `src/engine/web_scene_page.odin`: `scene_page_init` sets `page.orbit = orbit_fit_width(page.scene.camera, page.scene.fit_width, SCENE_PAGE_VERTICAL_FOV, page.aspect, SCENE_PAGE_DISTANCE_MAXIMUM)`, with `SCENE_PAGE_VERTICAL_FOV :: f32(math.PI / 3)` replacing the literal in `scene_page_camera` (the resize before the init's parse has set `page.aspect`).
- `data/demos/models/scene.sjson`: the camera gains `fit_width = 10`, the slab's width.
- `doc/render.md`, the scene files paragraph: `fit_width` as an optional key of `camera`, the width in metres the start view shows across the canvas, the page moving the camera back on a narrower canvas, within the zoom's maximum; the three other demos name none.
