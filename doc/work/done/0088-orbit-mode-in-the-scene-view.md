# 0088: An orbit mode in the scene view

Status: landed (2026-10-19, 39cbc49)

Goal: a scene can choose an orbit camera around its target instead of the fly camera, and a configuration can step back as well as forward, for the decimation demo's single furnace (user, 2026-10-19: "instead of fly camera can we revert it to orbiting around a single furnace, and arrow keys / ui buttons toggle between the furnaces"). Followed by 0089 (page), 0090 (app) and 0091 (data).

Verify:
- `./build.sh test` with the new tests, `./build.sh check`, `./build.sh web light`, `./build.sh smoke`.

## Specification

- `src/engine/render_camera.odin`: `orbit_turn :: proc(orbit: Orbit, delta: [2]f32, radians_per_unit: f32) -> Orbit` (yaw lowered by `delta.x`, pitch raised by `delta.y` and clamped to `ORBIT_PITCH_LIMIT`, the signs of `fly_turn`, so a drag right turns the model right and a drag down shows its top) and `orbit_zoom :: proc(orbit: Orbit, zoom, minimum, maximum: f32) -> Orbit` (distance times `math.exp(-zoom)`, clamped; a positive zoom closes in). Tests in `render_test.odin`: `test_orbit_turn_turns_and_clamps`, `test_orbit_zoom_scales_and_clamps`.
- `src/engine/scene.odin`: `Scene_Camera_Mode :: enum {Fly, Orbit}`, `Scene.camera_mode`, from an optional camera key `mode` (`"fly"` or `"orbit"`, anything else an error naming the value). Test in `scene_test.odin`: `test_parse_scene_camera_mode` (absent is fly, "orbit" parses, "walk" fails).
- `src/engine/scene_view.odin`: `SCENE_VIEW_DISTANCE_MINIMUM :: f32(1)`, `SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND :: f32(2)`, `SCENE_VIEW_ZOOM_PER_SECOND :: f32(1)`; `Scene_Input` gains `zoom: f32` (applied as given) and `previous_configuration: bool`; `Scene_View` gains `orbit: Orbit`, set at init to the fitted orbit the fly starts from. In orbit mode `scene_view_step` turns the orbit by `turn` at one radian per unit, by `{-walk.x, walk.y} * SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND * step_time` (D and the stick right go round to the right, up rises), zooms by `zoom + walk.z * SCENE_VIEW_ZOOM_PER_SECOND * step_time` within the minimum and `SCENE_VIEW_DISTANCE_MAXIMUM`, and ignores `move`; fly mode zooms nothing and stays as it is. In both modes `previous_configuration` steps the configuration back with wrap, after the forward cycle. `scene_view_camera` uses `orbit_camera` in orbit mode. Tests in `scene_view_test.odin`: `test_scene_view_orbit_mode_turns_and_zooms` (set `view.scene.camera_mode = .Orbit` and an orbit by hand), `test_scene_view_previous_configuration_wraps`.
- `doc/render.md`: the camera paragraph names the mode key and the orbit input.
