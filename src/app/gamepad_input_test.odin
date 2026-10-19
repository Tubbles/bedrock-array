#+build !js
package app

import "core:testing"

@(test)
test_gamepad_scene_input :: proc(t: ^testing.T) {
	snapshot := Gamepad_Snapshot {
		connected = true,
		left      = {0, -0.5},
		right     = {0.25, 0},
		buttons   = {.Dpad_Up},
	}
	input := gamepad_scene_input(snapshot, 0.5)
	testing.expect_value(t, input.walk, [3]f32{0, 1, 0.5})
	testing.expect_value(t, input.turn, [2]f32{0.25, 0})
}
