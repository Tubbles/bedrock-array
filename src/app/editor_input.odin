package app

// The pipeline editor's controls read from raylib and the pad
// (doc/build.md has the full list). The fly camera walks with W A S D,
// Space and Shift or the left stick, the d-pad rising and sinking while
// no panel or menu takes it, and looks with the mouse or the right stick.
// In brush mode the wheel or the shoulders set the radius and the right
// trigger paints and the left one erases, besides the mouse buttons.

import rl "shared:raylib"
import engine "../engine"

EDITOR_TRIGGER_THRESHOLD :: f32(0.5)

// A key with the modifiers it needs (an action bound to a key without Alt
// or Ctrl is not taken while one is held), the mouse buttons and the pad
// buttons that also press it. KEY_NULL binds no key.
Editor_Binding :: struct {
	action:       Editor_Action,
	key:          rl.KeyboardKey,
	alt, control: bool,
	mouse:        bit_set[rl.MouseButton],
	pad:          bit_set[Gamepad_Button],
}

// Every discrete binding of the editor, the one place they are set. W A S
// D, Space, Shift and the mouse's movement belong to the fly camera.
EDITOR_BINDINGS := [?]Editor_Binding {
	{action = .Up, key = .UP, pad = {.Dpad_Up}},
	{action = .Down, key = .DOWN, pad = {.Dpad_Down}},
	{action = .Left, key = .LEFT, pad = {.Dpad_Left}},
	{action = .Right, key = .RIGHT, pad = {.Dpad_Right}},
	{action = .Confirm, key = .ENTER, pad = {.South}},
	{action = .Move_Up, key = .UP, alt = true},
	{action = .Move_Down, key = .DOWN, alt = true},
	{action = .Leave, key = .ESCAPE, pad = {.East}},
	{action = .Toggle_Colour, key = .F, pad = {.North}},
	{action = .Toggle_List, key = .L},
	{action = .Panel, key = .TAB, pad = {.Back}},
	{action = .Insert_Menu, key = .I},
	{action = .Delete, key = .DELETE},
	{action = .Enable, key = .E},
	{action = .Cycle_Part, key = .P},
	{action = .Brush, key = .B, pad = {.West}},
	{action = .Save, key = .S, control = true, pad = {.Start}},
	{action = .Paint, mouse = {.LEFT}},
	{action = .Erase, mouse = {.RIGHT}},
}

// pressed holds the pad's buttons that went down this poll; triggers is
// the triggers of the previous poll, updated here. menus_open is whether
// the panel or the insert menu takes the d-pad, mouse_looks whether the
// mouse's movement turns the camera.
editor_read_input :: proc(brush_on, menus_open, mouse_looks: bool, snapshot: Gamepad_Snapshot, pressed: bit_set[Gamepad_Button], triggers: ^[2]f32, delta_time: f32) -> (input: Editor_Input) {
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	control := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	for binding in EDITOR_BINDINGS {
		if editor_binding_pressed(binding, alt, control, pressed) do input.pressed += {binding.action}
	}
	step_time := min(delta_time, engine.SCENE_VIEW_STEP_LIMIT)
	if brush_on {
		shoulders := f32(int(.Right_Shoulder in pressed)) - f32(int(.Left_Shoulder in pressed))
		input.radius_notches = rl.GetMouseWheelMove() + shoulders
		if editor_trigger_pressed(triggers[1], snapshot.triggers[1]) do input.pressed += {.Paint}
		if editor_trigger_pressed(triggers[0], snapshot.triggers[0]) do input.pressed += {.Erase}
	}
	triggers^ = snapshot.triggers
	input.walk = editor_walk(snapshot, !menus_open) * EDITOR_FLY_SPEED * step_time
	mouse := rl.GetMouseDelta() if mouse_looks else {}
	input.turn = [2]f32{mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL + snapshot.right * APP_STICK_TURN_RADIANS_PER_SECOND * step_time
	return input
}

editor_binding_pressed :: proc(binding: Editor_Binding, alt, control: bool, pad_pressed: bit_set[Gamepad_Button]) -> bool {
	if binding.pad & pad_pressed != {} do return true
	for button in binding.mouse {
		if rl.IsMouseButtonPressed(button) do return true
	}
	if binding.key == .KEY_NULL || binding.alt != alt || binding.control != control do return false
	return rl.IsKeyPressed(binding.key)
}

editor_trigger_pressed :: proc(before, now: f32) -> bool {
	return now > EDITOR_TRIGGER_THRESHOLD && before <= EDITOR_TRIGGER_THRESHOLD
}

// Right, up and forward, each from minus one to one: the keys and the left
// stick, and the d-pad's up and down when dpad_rises.
editor_walk :: proc(snapshot: Gamepad_Snapshot, dpad_rises: bool) -> [3]f32 {
	walk := [3]f32 {
		key_axis(rl.IsKeyDown(.D), rl.IsKeyDown(.A)) + snapshot.left.x,
		key_axis(rl.IsKeyDown(.SPACE), rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)),
		key_axis(rl.IsKeyDown(.W), rl.IsKeyDown(.S)) - snapshot.left.y,
	}
	if dpad_rises do walk.y += key_axis(.Dpad_Up in snapshot.buttons, .Dpad_Down in snapshot.buttons)
	return walk
}
