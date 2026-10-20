package app

// The pipeline editor's controls, read from raylib and the pad through
// EDITOR_BINDINGS, the table the on screen hints are drawn from too
// (editor_hints). Each row belongs to the modes it lists. A pad binding
// with pad_modifier needs the left shoulder held; in the modes of
// EDITOR_PAD_MODIFIER_MODES a pad binding without it is not taken while
// the shoulder is held.

import "core:fmt"
import "core:strings"
import rl "shared:raylib"
import engine "../engine"

EDITOR_TRIGGER_THRESHOLD :: f32(0.5)

// What the editor is doing, which decides the actions it takes.
Editor_Mode :: enum {
	Walk,
	// Walking after a leave warned of unsaved edits.
	Leave_Warning,
	Brush,
	Panel,
	Op_Menu,
}

Editor_Trigger :: enum {
	None,
	Left,
	Right,
}

// One binding of an action in some modes: a key with the modifiers it
// needs (an action bound to a key without Alt or Ctrl is not taken while
// one is held), mouse buttons, pad buttons, a trigger. The axes (walk,
// look, rise and sink, the radius) are read by editor_read_input from
// the rows of their action; keys_text and pad_text name what those rows
// read where the key and the pad fields cannot.
Editor_Binding :: struct {
	action:       Editor_Action,
	modes:        bit_set[Editor_Mode],
	label:        string,
	key:          rl.KeyboardKey,
	alt, control: bool,
	mouse:        bit_set[rl.MouseButton],
	pad:          bit_set[Gamepad_Button],
	pad_modifier: bool,
	trigger:      Editor_Trigger,
	keys_text:    string,
	pad_text:     string,
}

@(private = "file")
WALKING :: bit_set[Editor_Mode]{.Walk, .Leave_Warning}
@(private = "file")
EVERY_MODE :: bit_set[Editor_Mode]{.Walk, .Leave_Warning, .Brush, .Panel, .Op_Menu}

EDITOR_PAD_MODIFIER_MODES :: bit_set[Editor_Mode]{.Walk, .Leave_Warning, .Panel, .Op_Menu}

// The actions each mode's handling takes (editor_step), every other
// action of a frame dropped.
EDITOR_MODE_ACTIONS := [Editor_Mode]bit_set[Editor_Action] {
	.Walk          = {.Walk, .Look, .Rise_Sink, .Panel, .Insert_Menu, .Delete, .Move_Up, .Move_Down, .Enable, .Cycle_Part, .Brush, .Toggle_Colour, .Toggle_List, .Save, .Leave},
	.Leave_Warning = {.Walk, .Look, .Rise_Sink, .Panel, .Insert_Menu, .Delete, .Move_Up, .Move_Down, .Enable, .Cycle_Part, .Brush, .Toggle_Colour, .Toggle_List, .Save, .Leave},
	.Brush         = {.Walk, .Look, .Rise_Sink, .Paint, .Erase, .Radius, .Cycle_Part, .Toggle_List, .Brush, .Toggle_Colour, .Save, .Leave},
	.Panel         = {.Walk, .Look, .Rise_Sink, .Up, .Down, .Left, .Right, .Confirm, .Panel, .Toggle_Colour, .Save, .Leave},
	.Op_Menu       = {.Walk, .Look, .Rise_Sink, .Up, .Down, .Confirm, .Insert_Menu, .Leave},
}

// Every binding of the editor, the one place they are set, in the order
// the hints show them.
EDITOR_BINDINGS := [?]Editor_Binding {
	{action = .Walk, modes = EVERY_MODE, label = "walk", keys_text = "W A S D", pad_text = "left stick"},
	{action = .Look, modes = EVERY_MODE, label = "look", keys_text = "mouse", pad_text = "right stick"},
	{action = .Rise_Sink, modes = WALKING + {.Brush}, label = "rise, sink", keys_text = "Space Shift", pad = {.Dpad_Up, .Dpad_Down}},
	{action = .Rise_Sink, modes = {.Panel, .Op_Menu}, label = "rise, sink", keys_text = "Space Shift", pad = {.Dpad_Up, .Dpad_Down}, pad_modifier = true},
	{action = .Up, modes = {.Panel}, label = "previous key", key = .UP, pad = {.Dpad_Up}},
	{action = .Down, modes = {.Panel}, label = "next key", key = .DOWN, pad = {.Dpad_Down}},
	{action = .Left, modes = {.Panel}, label = "lower", key = .LEFT, pad = {.Dpad_Left}},
	{action = .Right, modes = {.Panel}, label = "raise", key = .RIGHT, pad = {.Dpad_Right}},
	{action = .Confirm, modes = {.Panel}, label = "reset key", key = .ENTER, pad = {.South}},
	{action = .Up, modes = {.Op_Menu}, label = "previous op", key = .UP, pad = {.Dpad_Up}},
	{action = .Down, modes = {.Op_Menu}, label = "next op", key = .DOWN, pad = {.Dpad_Down}},
	{action = .Confirm, modes = {.Op_Menu}, label = "insert it", key = .ENTER, pad = {.South}},
	{action = .Paint, modes = {.Brush}, label = "paint", mouse = {.LEFT}, trigger = .Right},
	{action = .Erase, modes = {.Brush}, label = "erase", mouse = {.RIGHT}, trigger = .Left},
	{action = .Radius, modes = {.Brush}, label = "radius", keys_text = "wheel", pad = {.Left_Shoulder, .Right_Shoulder}},
	{action = .Panel, modes = WALKING, label = "key panel", key = .TAB, pad = {.Back}},
	{action = .Panel, modes = {.Panel}, label = "close panel", key = .TAB, pad = {.Back}},
	{action = .Insert_Menu, modes = WALKING, label = "insert step", key = .I, pad = {.South}, pad_modifier = true},
	{action = .Insert_Menu, modes = {.Op_Menu}, label = "close menu", key = .I, pad = {.South}, pad_modifier = true},
	{action = .Delete, modes = WALKING, label = "delete step", key = .DELETE, pad = {.Back}, pad_modifier = true},
	{action = .Move_Up, modes = WALKING, label = "move step up", key = .UP, alt = true, pad = {.Dpad_Up}, pad_modifier = true},
	{action = .Move_Down, modes = WALKING, label = "move step down", key = .DOWN, alt = true, pad = {.Dpad_Down}, pad_modifier = true},
	{action = .Enable, modes = WALKING, label = "enable, disable", key = .E, pad = {.North}, pad_modifier = true},
	{action = .Cycle_Part, modes = WALKING, label = "next part", key = .P, pad = {.West}, pad_modifier = true},
	{action = .Cycle_Part, modes = {.Brush}, label = "next part", key = .P, pad = {.Dpad_Right}},
	{action = .Brush, modes = WALKING, label = "brush", key = .B, pad = {.West}},
	{action = .Brush, modes = {.Brush}, label = "brush off", key = .B, pad = {.West}},
	{action = .Toggle_Colour, modes = WALKING + {.Brush, .Panel}, label = "colours", key = .F, pad = {.North}},
	{action = .Toggle_List, modes = WALKING, label = "step list", key = .L, pad = {.Start}, pad_modifier = true},
	{action = .Toggle_List, modes = {.Brush}, label = "step list", key = .L, pad = {.Dpad_Left}},
	{action = .Save, modes = WALKING + {.Brush, .Panel}, label = "save", key = .S, control = true, pad = {.Start}},
	{action = .Leave, modes = {.Walk}, label = "leave", key = .ESCAPE, pad = {.East}},
	{action = .Leave, modes = {.Leave_Warning}, label = "discard, leave", key = .ESCAPE, pad = {.East}},
	{action = .Leave, modes = {.Brush}, label = "brush off", key = .ESCAPE, pad = {.East}},
	{action = .Leave, modes = {.Panel}, label = "close panel", key = .ESCAPE, pad = {.East}},
	{action = .Leave, modes = {.Op_Menu}, label = "close menu", key = .ESCAPE, pad = {.East}},
}

// The insert menu, then the panel, then the brush, then a warned leave.
editor_mode :: proc(editor: ^Editor) -> Editor_Mode {
	switch {
	case editor.op_menu_open: return .Op_Menu
	case editor.panel_open: return .Panel
	case editor.brush.on: return .Brush
	case editor.leave_warned: return .Leave_Warning
	}
	return .Walk
}

// The mode's row of the action, found false when the mode has none.
editor_binding_of :: proc(mode: Editor_Mode, action: Editor_Action) -> (binding: Editor_Binding, found: bool) {
	for row in EDITOR_BINDINGS {
		if row.action == action && mode in row.modes do return row, true
	}
	return {}, false
}

// pressed holds the pad's buttons that went down this poll; triggers is
// the triggers of the previous poll, updated here. mouse_looks is whether
// the mouse's movement turns the camera.
editor_read_input :: proc(mode: Editor_Mode, mouse_looks: bool, snapshot: Gamepad_Snapshot, pressed: bit_set[Gamepad_Button], triggers: ^[2]f32, delta_time: f32) -> (input: Editor_Input) {
	alt := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT)
	control := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	modifier := .Left_Shoulder in snapshot.buttons
	modifier_blocks := mode in EDITOR_PAD_MODIFIER_MODES
	for row in EDITOR_BINDINGS {
		if mode not_in row.modes do continue
		pad_ready := row.pad_modifier == modifier || (!row.pad_modifier && !modifier_blocks)
		if editor_binding_pressed(row, alt, control, pressed if pad_ready else {}) do input.pressed += {row.action}
		if editor_trigger_of(row, triggers^, snapshot.triggers) do input.pressed += {row.action}
	}
	triggers^ = snapshot.triggers
	step_time := min(delta_time, engine.SCENE_VIEW_STEP_LIMIT)
	if radius, found := editor_binding_of(mode, .Radius); found {
		shoulders := f32(int(.Right_Shoulder in pressed & radius.pad)) - f32(int(.Left_Shoulder in pressed & radius.pad))
		input.radius_notches = rl.GetMouseWheelMove() + shoulders
	}
	input.walk = editor_walk(mode, snapshot, modifier) * EDITOR_FLY_SPEED * step_time
	mouse := rl.GetMouseDelta() if mouse_looks else {}
	input.turn = [2]f32{mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL + snapshot.right * APP_STICK_TURN_RADIANS_PER_SECOND * step_time
	return input
}

// The axes are read elsewhere, so their rows press nothing here.
editor_binding_pressed :: proc(binding: Editor_Binding, alt, control: bool, pad_pressed: bit_set[Gamepad_Button]) -> bool {
	if binding.action == .Rise_Sink || binding.action == .Radius do return false
	if binding.pad & pad_pressed != {} do return true
	for button in binding.mouse {
		if rl.IsMouseButtonPressed(button) do return true
	}
	if binding.key == .KEY_NULL || binding.alt != alt || binding.control != control do return false
	return rl.IsKeyPressed(binding.key)
}

editor_trigger_of :: proc(binding: Editor_Binding, before, now: [2]f32) -> bool {
	switch binding.trigger {
	case .None: return false
	case .Left: return editor_trigger_pressed(before[0], now[0])
	case .Right: return editor_trigger_pressed(before[1], now[1])
	}
	return false
}

editor_trigger_pressed :: proc(before, now: f32) -> bool {
	return now > EDITOR_TRIGGER_THRESHOLD && before <= EDITOR_TRIGGER_THRESHOLD
}

// Right, up and forward, each from minus one to one: the keys and the left
// stick, and the d-pad's up and down as the mode's rise and sink row has
// them, with or without the left shoulder held.
editor_walk :: proc(mode: Editor_Mode, snapshot: Gamepad_Snapshot, modifier: bool) -> [3]f32 {
	walk := [3]f32 {
		key_axis(rl.IsKeyDown(.D), rl.IsKeyDown(.A)) + snapshot.left.x,
		key_axis(rl.IsKeyDown(.SPACE), rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)),
		key_axis(rl.IsKeyDown(.W), rl.IsKeyDown(.S)) - snapshot.left.y,
	}
	rise, found := editor_binding_of(mode, .Rise_Sink)
	if found && rise.pad_modifier == modifier {
		walk.y += key_axis(.Dpad_Up in snapshot.buttons & rise.pad, .Dpad_Down in snapshot.buttons & rise.pad)
	}
	return walk
}

// One hint of the bar: what to press on the keyboard and the mouse, on
// the pad, and what it does.
Editor_Hint :: struct {
	keys, pad, action: string,
	binding_action:    Editor_Action,
}

// The editor's mode's hints, in the table's order.
editor_hints :: proc(editor: ^Editor) -> []Editor_Hint {
	return editor_mode_hints(editor_mode(editor))
}

editor_mode_hints :: proc(mode: Editor_Mode) -> []Editor_Hint {
	hints := make([dynamic]Editor_Hint, context.temp_allocator)
	for row in EDITOR_BINDINGS {
		if mode in row.modes do append(&hints, Editor_Hint{editor_keys_name(row), editor_pad_name(row), row.label, row.action})
	}
	return hints[:]
}

// The hint's text: "keys / pad: action".
editor_hint_text :: proc(hint: Editor_Hint) -> string {
	return fmt.tprintf("%s / %s: %s", hint.keys, hint.pad, hint.action)
}

EDITOR_MODE_NAMES := [Editor_Mode]string {
	.Walk          = "walk",
	.Leave_Warning = "unsaved",
	.Brush         = "brush",
	.Panel         = "key panel",
	.Op_Menu       = "insert menu",
}

editor_keys_name :: proc(binding: Editor_Binding) -> string {
	if binding.keys_text != "" do return binding.keys_text
	names := make([dynamic]string, context.temp_allocator)
	if binding.key != .KEY_NULL {
		prefix := "Ctrl " if binding.control else "Alt " if binding.alt else ""
		append(&names, fmt.tprintf("%s%s", prefix, editor_key_name(binding.key)))
	}
	if .LEFT in binding.mouse do append(&names, "left click")
	if .RIGHT in binding.mouse do append(&names, "right click")
	return strings.join(names[:], " ", context.temp_allocator)
}

editor_key_name :: proc(key: rl.KeyboardKey) -> string {
	#partial switch key {
	case .UP: return "Up"
	case .DOWN: return "Down"
	case .LEFT: return "Left"
	case .RIGHT: return "Right"
	case .ENTER: return "Enter"
	case .ESCAPE: return "Esc"
	case .TAB: return "Tab"
	case .DELETE: return "Delete"
	case .SPACE: return "Space"
	}
	if key >= .A && key <= .Z do return fmt.tprintf("%c", rune('A' + int(key) - int(rl.KeyboardKey.A)))
	return fmt.tprintf("%v", key)
}

EDITOR_PAD_NAMES := [Gamepad_Button]string {
	.South          = "A",
	.East           = "B",
	.West           = "X",
	.North          = "Y",
	.Back           = "Back",
	.Start          = "Start",
	.Left_Shoulder  = "LB",
	.Right_Shoulder = "RB",
	.Dpad_Up        = "up",
	.Dpad_Down      = "down",
	.Dpad_Left      = "left",
	.Dpad_Right     = "right",
}

// The buttons with "d-pad" once before the d-pad's directions, "LB +"
// before them for a binding that needs the left shoulder held.
editor_pad_name :: proc(binding: Editor_Binding) -> string {
	if binding.pad_text != "" do return binding.pad_text
	names := make([dynamic]string, context.temp_allocator)
	if binding.pad_modifier do append(&names, "LB +")
	if binding.pad & {.Dpad_Up, .Dpad_Down, .Dpad_Left, .Dpad_Right} != {} do append(&names, "d-pad")
	for button in binding.pad do append(&names, EDITOR_PAD_NAMES[button])
	switch binding.trigger {
	case .None:
	case .Left: append(&names, "LT")
	case .Right: append(&names, "RT")
	}
	return strings.join(names[:], " ", context.temp_allocator)
}
