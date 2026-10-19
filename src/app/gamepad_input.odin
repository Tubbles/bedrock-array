package app

import engine "../engine"

APP_STICK_TURN_RADIANS_PER_SECOND :: f32(2)

// The page's mapping (engine scene_page_gamepad): the left stick walks, the
// d-pad rises and sinks, the right stick turns.
gamepad_scene_input :: proc(snapshot: Gamepad_Snapshot, delta_time: f32) -> engine.Scene_Input {
	vertical := key_axis(.Dpad_Up in snapshot.buttons, .Dpad_Down in snapshot.buttons)
	return {
		walk = {snapshot.left.x, vertical, -snapshot.left.y},
		turn = snapshot.right * APP_STICK_TURN_RADIANS_PER_SECOND * delta_time,
	}
}
