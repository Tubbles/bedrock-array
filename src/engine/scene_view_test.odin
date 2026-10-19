#+build !js
package engine

import "core:math"
import "core:testing"

@(test)
test_scene_view_step_turns_then_walks :: proc(t: ^testing.T) {
	view: Scene_View
	scene_view_step(&view, {turn = {0, 0.25}}, 1)
	testing.expect(t, math.abs(view.fly.pitch - 0.25) < 1e-5)
	// A quarter turn left, then a forward walk along the new facing, the
	// step clamped to SCENE_VIEW_STEP_LIMIT seconds.
	view.fly = Fly{}
	scene_view_step(&view, {walk = {0, 0, 1}, turn = {-math.PI / 2, 0}}, 10)
	testing.expect(t, math.abs(view.fly.position.x + SCENE_VIEW_FLY_SPEED * SCENE_VIEW_STEP_LIMIT) < 1e-4)
	testing.expect(t, math.abs(view.fly.position.z) < 1e-4)
}

@(test)
test_scene_view_step_moves_unscaled :: proc(t: ^testing.T) {
	for delta_time in ([?]f32{0, 1.0 / 60, 10}) {
		view: Scene_View
		scene_view_step(&view, {move = {0, 0, 2}}, delta_time)
		testing.expect(t, math.abs(view.fly.position.z + 2) < 1e-4)
		testing.expect(t, math.abs(view.fly.position.x) < 1e-4)
	}
}

@(test)
test_scene_view_label_screen :: proc(t: ^testing.T) {
	view: Scene_View
	view.scene.labels = []Scene_Label{{text = "plaque", position = {0, 0, -5}}}
	pixel, visible := scene_view_label_screen(&view, 0, {800, 600})
	testing.expect(t, visible)
	testing.expect(t, math.abs(pixel.x - 400) < 1e-2)
	testing.expect(t, math.abs(pixel.y - 300) < 1e-2)
	_, out_of_range := scene_view_label_screen(&view, 1, {800, 600})
	testing.expect(t, !out_of_range)
}

@(test)
test_scene_view_cycle_configuration :: proc(t: ^testing.T) {
	view: Scene_View
	view.scene.configurations = []string{"none", "fill", "smart"}
	testing.expect_value(t, scene_view_configuration_count(&view), 3)
	testing.expect_value(t, scene_view_configuration_name(&view), "none")
	expected := [?]string{"fill", "smart", "none"}
	for name, index in expected {
		scene_view_step(&view, {cycle_configuration = true}, 0)
		testing.expect_value(t, view.configuration, (index + 1) % 3)
		testing.expect_value(t, scene_view_configuration_name(&view), name)
	}
	scene_view_step(&view, {}, 0)
	testing.expect_value(t, view.configuration, 0)
	plain: Scene_View
	scene_view_step(&plain, {cycle_configuration = true}, 0)
	testing.expect_value(t, plain.configuration, 0)
	testing.expect_value(t, scene_view_configuration_count(&plain), 1)
	testing.expect_value(t, scene_view_configuration_name(&plain), "")
}

@(test)
test_scene_view_orbit_mode_turns_and_zooms :: proc(t: ^testing.T) {
	view: Scene_View
	view.scene.camera_mode = .Orbit
	view.orbit = Orbit{target = {1, 2, 3}, yaw = 0, pitch = 0, distance = 4}
	// D held for the clamped step goes round to the right, up rises, forward zooms in, the move does nothing.
	scene_view_step(&view, {walk = {1, 1, 1}, move = {5, 5, 5}}, 10)
	angle := SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND * SCENE_VIEW_STEP_LIMIT
	testing.expect(t, math.abs(view.orbit.yaw - angle) < 1e-5)
	testing.expect(t, math.abs(view.orbit.pitch - angle) < 1e-5)
	testing.expect(t, math.abs(view.orbit.distance - 4 * math.exp(-SCENE_VIEW_ZOOM_PER_SECOND * SCENE_VIEW_STEP_LIMIT)) < 1e-4)
	testing.expect_value(t, view.fly, Fly{})
	// A turn and a zoom apply as given, the zoom within the limits.
	view.orbit = Orbit{distance = 4}
	scene_view_step(&view, {turn = {0.5, 0.25}, zoom = math.ln(f32(2))}, 0)
	testing.expect(t, math.abs(view.orbit.yaw + 0.5) < 1e-5)
	testing.expect(t, math.abs(view.orbit.pitch - 0.25) < 1e-5)
	testing.expect(t, math.abs(view.orbit.distance - 2) < 1e-4)
	scene_view_step(&view, {zoom = 100}, 0)
	testing.expect_value(t, view.orbit.distance, SCENE_VIEW_DISTANCE_MINIMUM)
	scene_view_step(&view, {zoom = -100}, 0)
	testing.expect_value(t, view.orbit.distance, SCENE_VIEW_DISTANCE_MAXIMUM)
	camera := scene_view_camera(&view)
	testing.expect_value(t, camera.position, orbit_camera(view.orbit, SCENE_VIEW_VERTICAL_FOV, 0.1, 100).position)
	// Fly mode zooms nothing.
	fly_view: Scene_View
	fly_view.orbit = Orbit{distance = 4}
	scene_view_step(&fly_view, {zoom = 1}, 0)
	testing.expect_value(t, fly_view.orbit.distance, 4)
	testing.expect_value(t, fly_view.fly, Fly{})
}

@(test)
test_scene_view_previous_configuration_wraps :: proc(t: ^testing.T) {
	view: Scene_View
	view.scene.configurations = []string{"none", "fill", "smart"}
	expected := [?]int{2, 1, 0, 2}
	for configuration in expected {
		scene_view_step(&view, {previous_configuration = true}, 0)
		testing.expect_value(t, view.configuration, configuration)
	}
	scene_view_step(&view, {cycle_configuration = true, previous_configuration = true}, 0)
	testing.expect_value(t, view.configuration, 2)
	plain: Scene_View
	scene_view_step(&plain, {previous_configuration = true}, 0)
	testing.expect_value(t, plain.configuration, 0)
}
