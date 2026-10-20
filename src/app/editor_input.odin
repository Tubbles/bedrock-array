package app

// The pipeline editor's controls read from raylib and the pad
// (doc/build.md has the full list). In brush mode the mouse and the right
// stick move the brush's cursor, the left button or the right trigger
// paints, the right button or the left trigger erases, and the wheel or
// the shoulders set the radius, instead of turning, zooming and changing
// the grid.

import rl "shared:raylib"
import engine "../engine"

EDITOR_TRIGGER_THRESHOLD :: f32(0.5)
// Points per second the right stick moves the brush's cursor.
EDITOR_STICK_CURSOR_SPEED :: f32(600)

// pressed holds the pad's buttons that went down this poll; triggers is
// the triggers of the previous poll, updated here.
editor_read_input :: proc(brush_on: bool, snapshot: Gamepad_Snapshot, pressed: bit_set[Gamepad_Button], triggers: ^[2]f32, delta_time: f32) -> (input: Editor_Input) {
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	input.up = .Dpad_Up in pressed || (!alt && rl.IsKeyPressed(.UP))
	input.down = .Dpad_Down in pressed || (!alt && rl.IsKeyPressed(.DOWN))
	input.move_up = alt && rl.IsKeyPressed(.UP)
	input.move_down = alt && rl.IsKeyPressed(.DOWN)
	input.left = .Dpad_Left in pressed || rl.IsKeyPressed(.LEFT)
	input.right = .Dpad_Right in pressed || rl.IsKeyPressed(.RIGHT)
	input.confirm = .South in pressed || rl.IsKeyPressed(.ENTER)
	input.leave = .East in pressed || rl.IsKeyPressed(.ESCAPE)
	input.toggle_colour = .North in pressed || rl.IsKeyPressed(.F)
	input.panel = .Back in pressed || rl.IsKeyPressed(.TAB)
	input.brush = .West in pressed || rl.IsKeyPressed(.B)
	input.save = .Start in pressed || rl.IsKeyPressed(.S)
	input.insert_menu = rl.IsKeyPressed(.I)
	input.delete = rl.IsKeyPressed(.DELETE)
	input.enable = rl.IsKeyPressed(.E)
	input.cycle_part = rl.IsKeyPressed(.P)
	input.add = rl.IsKeyPressed(.PAGE_UP)
	input.drop = rl.IsKeyPressed(.PAGE_DOWN)
	shoulders := f32(int(.Right_Shoulder in pressed)) - f32(int(.Left_Shoulder in pressed))
	input.window = render_size()
	input.pixels_per_point = f32(input.window.x) / f32(max(screen_size().x, 1))
	step_time := min(delta_time, engine.SCENE_VIEW_STEP_LIMIT)
	if brush_on {
		input.radius_notches = rl.GetMouseWheelMove() + shoulders
		mouse_delta := rl.GetMouseDelta()
		input.cursor = rl.GetMousePosition()
		input.cursor_set = mouse_delta != {}
		input.cursor_move = snapshot.right * EDITOR_STICK_CURSOR_SPEED * step_time
		input.paint = rl.IsMouseButtonPressed(.LEFT) || editor_trigger_pressed(triggers[1], snapshot.triggers[1])
		input.erase = rl.IsMouseButtonPressed(.RIGHT) || editor_trigger_pressed(triggers[0], snapshot.triggers[0])
	} else {
		input.add = input.add || .Right_Shoulder in pressed
		input.drop = input.drop || .Left_Shoulder in pressed
		editor_camera_turn_and_zoom(&input, snapshot, step_time)
	}
	editor_camera_keys(&input, snapshot, step_time)
	triggers^ = snapshot.triggers
	return input
}

editor_trigger_pressed :: proc(before, now: f32) -> bool {
	return now > EDITOR_TRIGGER_THRESHOLD && before <= EDITOR_TRIGGER_THRESHOLD
}

// Outside brush mode: the mouse turns while its left button is down, the
// wheel zooms and the right stick turns.
editor_camera_turn_and_zoom :: proc(input: ^Editor_Input, snapshot: Gamepad_Snapshot, step_time: f32) {
	if rl.IsMouseButtonDown(.LEFT) {
		mouse := rl.GetMouseDelta()
		input.turn += [2]f32{mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL
	}
	input.zoom += rl.GetMouseWheelMove() * APP_WHEEL_ZOOM_PER_NOTCH
	input.turn += snapshot.right * APP_STICK_TURN_RADIANS_PER_SECOND * step_time
}

// Always: A and D go round, Space and Shift rise and sink, the equals and
// minus keys zoom, the left stick goes round and zooms. The letters the
// demos walk with are the editor's commands.
editor_camera_keys :: proc(input: ^Editor_Input, snapshot: Gamepad_Snapshot, step_time: f32) {
	round := key_axis(rl.IsKeyDown(.D), rl.IsKeyDown(.A)) + snapshot.left.x
	rise := key_axis(rl.IsKeyDown(.SPACE), rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))
	zoom := key_axis(rl.IsKeyDown(.EQUAL) || rl.IsKeyDown(.KP_ADD), rl.IsKeyDown(.MINUS) || rl.IsKeyDown(.KP_SUBTRACT)) - snapshot.left.y
	input.turn += [2]f32{-round, rise} * engine.SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND * step_time
	input.zoom += zoom * engine.SCENE_VIEW_ZOOM_PER_SECOND * step_time
}
