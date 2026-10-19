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
