package app

// The pipeline editor's frame step: the fly camera, the selection under the
// crosshair, the key panel, the insert menu, the brush and the commands
// read from one frame's input, each edit marking the editor unsaved and
// rerunning from the step it changed.

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import engine "../engine"
import pipeline "../pipeline"

EDITOR_BRUSH_RADIUS_DEFAULT :: f32(0.01)
EDITOR_BRUSH_RADIUS_MINIMUM :: f32(0.002)
EDITOR_BRUSH_RADIUS_MAXIMUM :: f32(0.05)
// The radius is scaled by this per wheel notch or shoulder press.
EDITOR_BRUSH_RADIUS_FACTOR :: f32(1.25)
EDITOR_LEAVE_WARNING :: "unsaved: leave again to discard, Ctrl S to save"

// What the brush's last pick was made from, so it is made again only
// when one of them changes: the crosshair moves with the fly.
Editor_Pick_Key :: struct {
	fly:        engine.Fly,
	step:       int,
	generation: int,
}

// The brush paints strokes on the selected step, picking its machine under
// the crosshair. position is the hit in the machine's own frame, counts
// the triangles each stroke takes, as of counts_key.
Editor_Brush :: struct {
	on:         bool,
	radius:     f32,
	hit:        bool,
	position:   [3]f32,
	pick_key:   Editor_Pick_Key,
	picked:     bool,
	counts:     []int,
	counts_key: [2]int,
	counted:    bool,
}

// What a binding does (EDITOR_BINDINGS in editor_input.odin).
Editor_Action :: enum {
	Up,
	Down,
	Left,
	Right,
	Confirm,
	Move_Up,
	Move_Down,
	Leave,
	Toggle_Colour,
	Toggle_List,
	Panel,
	Insert_Menu,
	Delete,
	Enable,
	Cycle_Part,
	Brush,
	Save,
	Paint,
	Erase,
}

// One frame's presses. walk is metres in the fly's frame (right, up,
// forward) and turn radians, both already scaled by the frame time.
Editor_Input :: struct {
	pressed:        bit_set[Editor_Action],
	radius_notches: f32,
	walk:           [3]f32,
	turn:           [2]f32,
}

Editor_Command :: enum {
	None,
	Leave,
}

// A leave closes the insert menu, the panel or the brush first. With
// unsaved edits the first leave warns, the next one leaves.
editor_step :: proc(editor: ^Editor, input: Editor_Input) -> Editor_Command {
	editor.frames += 1
	if .Leave in input.pressed && editor_leave(editor) do return .Leave
	editor.fly = engine.fly_walk(engine.fly_turn(editor.fly, input.turn, 1), input.walk, 1)
	if editor.op_menu_open {
		editor_op_menu_step(editor, input)
	} else {
		if editor.panel_open do editor_panel_step(editor, input)
		else do editor_reorder_step(editor, input)
		editor_command_step(editor, input)
		editor_brush_step(editor, input)
	}
	pipeline.run_poll(&editor.run)
	editor_sync_machines(editor)
	editor_select_under_crosshair(editor)
	editor_refresh_counts(editor)
	return .None
}

editor_set_message :: proc(editor: ^Editor, text: string) {
	delete(editor.message)
	editor.message = fmt.aprint(text)
}

// true when the editor is to be left.
editor_leave :: proc(editor: ^Editor) -> bool {
	switch {
	case editor.op_menu_open: editor.op_menu_open = false
	case editor.panel_open: editor.panel_open = false
	case editor.brush.on: editor.brush.on = false
	case editor.unsaved && !editor.leave_warned:
		editor.leave_warned = true
		editor_set_message(editor, EDITOR_LEAVE_WARNING)
	case: return true
	}
	return false
}

// Every edit of the steps from index on: unsaved, and rerun from there.
editor_edited :: proc(editor: ^Editor, index: int) {
	editor.unsaved = true
	editor.leave_warned = false
	editor_set_message(editor, "")
	editor_run_from(editor, index)
}

// The selection and the machines follow a change of the steps' order. A
// deleted step's meshes are released.
editor_apply_change :: proc(editor: ^Editor, change: Editor_Change) {
	editor.selected = max(editor_index_after(change, editor.selected), 0)
	moved := make([dynamic]Editor_Machine, len(editor.run.pipeline.steps))
	for &machine, index in editor.machines {
		after := editor_index_after(change, index)
		if after >= 0 && after < len(moved) {
			moved[after] = machine
			continue
		}
		editor_release_upload(editor, &machine.upload)
		delete(machine.upload.meshes)
	}
	delete(editor.machines)
	editor.machines = moved
}

editor_selected_step :: proc(editor: ^Editor) -> ^pipeline.Step {
	return &editor.run.pipeline.steps[editor.selected]
}

// The selected step is the machine the crosshair meets first, else the
// one nearest the camera. It holds still while the panel, the insert menu
// or the brush works on it. A new selection starts the panel at its first row.
editor_select_under_crosshair :: proc(editor: ^Editor) {
	if editor.brush.on || editor.panel_open || editor.op_menu_open || len(editor.machines) == 0 do return
	boxes := make([]Editor_Bounds, len(editor.machines), context.temp_allocator)
	for machine, index in editor.machines do boxes[index] = editor_world_bounds(machine.bounds, index)
	camera := editor_camera(editor)
	picked := editor_pick_box(camera.position, linalg.normalize(camera.target - camera.position), boxes)
	if picked == editor.selected do return
	editor.selected = picked
	editor.panel_row = 0
}

// The index of the box the ray meets nearest, else of the box whose middle
// lies nearest the origin, -1 for no boxes.
editor_pick_box :: proc(origin, direction: [3]f32, boxes: []Editor_Bounds) -> int {
	picked, picked_distance := -1, max(f32)
	for box, index in boxes {
		distance, met := editor_ray_box(origin, direction, box)
		if met && distance < picked_distance do picked, picked_distance = index, distance
	}
	if picked >= 0 do return picked
	for box, index in boxes {
		distance := linalg.length((box.minimum + box.maximum) / 2 - origin)
		if distance < picked_distance do picked, picked_distance = index, distance
	}
	return picked
}

// The slab test: the distance along the ray to where it enters the box, 0
// from inside it, met false when it passes by or the box lies behind.
editor_ray_box :: proc(origin, direction: [3]f32, box: Editor_Bounds) -> (distance: f32, met: bool) {
	near, far := f32(0), max(f32)
	for axis in 0 ..< 3 {
		if math.abs(direction[axis]) < 1e-9 {
			if origin[axis] < box.minimum[axis] || origin[axis] > box.maximum[axis] do return 0, false
			continue
		}
		first := (box.minimum[axis] - origin[axis]) / direction[axis]
		second := (box.maximum[axis] - origin[axis]) / direction[axis]
		near, far = max(near, min(first, second)), min(far, max(first, second))
	}
	return near, near <= far
}

// Alt with up or down moves the selected step.
editor_reorder_step :: proc(editor: ^Editor, input: Editor_Input) {
	if len(editor.run.pipeline.steps) == 0 do return
	direction := int(.Move_Down in input.pressed) - int(.Move_Up in input.pressed)
	if direction == 0 do return
	before := editor.selected
	moved := editor_move_step(&editor.run.pipeline.steps, before, direction)
	if moved == before do return
	editor_apply_change(editor, {kind = .Swap, index = before, other = moved})
	editor_edited(editor, min(before, moved))
}

// Up and down choose the key, left and right change it, Enter resets it.
editor_panel_step :: proc(editor: ^Editor, input: Editor_Input) {
	step := editor_selected_step(editor)
	keys := EDITOR_OP_KEYS[step.op]
	if len(keys) == 0 do return
	editor.panel_row = editor_cycle(editor.panel_row, len(keys), int(.Down in input.pressed) - int(.Up in input.pressed))
	key := keys[editor.panel_row]
	direction := int(.Right in input.pressed) - int(.Left in input.pressed)
	confirm := .Confirm in input.pressed
	if confirm do editor_reset_key(step, key, editor_part_names(editor))
	else if direction != 0 do editor_adjust_key(step, key, direction, editor_part_names(editor))
	if confirm || direction != 0 do editor_edited(editor, editor.selected)
}

// Up and down choose the op, Enter inserts it after the selected step and
// selects it, the menu's key closes it.
editor_op_menu_step :: proc(editor: ^Editor, input: Editor_Input) {
	if .Insert_Menu in input.pressed {
		editor.op_menu_open = false
		return
	}
	editor.op_menu_row = editor_cycle(editor.op_menu_row, len(EDITOR_INSERTABLE_OPS), int(.Down in input.pressed) - int(.Up in input.pressed))
	if .Confirm not_in input.pressed do return
	index := editor_insert_step(&editor.run.pipeline.steps, editor.selected, EDITOR_INSERTABLE_OPS[editor.op_menu_row], editor_part_names(editor))
	editor.op_menu_open = false
	if index < 0 do return
	editor_apply_change(editor, {kind = .Insert, index = index})
	editor.selected = index
	editor.panel_row = 0
	editor.brush.on = false
	editor_edited(editor, index)
}

editor_command_step :: proc(editor: ^Editor, input: Editor_Input) {
	pressed := input.pressed
	if .Toggle_Colour in pressed do editor.false_colour = !editor.false_colour
	if .Toggle_List in pressed do editor.list_open = !editor.list_open
	if .Panel in pressed {
		editor.panel_open = !editor.panel_open
		editor.panel_row = 0
	}
	if .Insert_Menu in pressed {
		editor.op_menu_open = true
		editor.panel_open = false
	}
	if .Enable in pressed && editor.selected > 0 {
		editor_toggle_step(editor_selected_step(editor))
		editor_edited(editor, editor.selected)
	}
	if .Cycle_Part in pressed {
		step := editor_selected_step(editor)
		if step.op == .Assign || step.op == .Close {
			editor_cycle_part(step, editor_part_names(editor), 1)
			editor_edited(editor, editor.selected)
		}
	}
	if .Delete in pressed do editor_delete_selected(editor)
	if .Brush in pressed do editor_toggle_brush(editor)
	if .Save in pressed do editor_save(editor)
}

editor_delete_selected :: proc(editor: ^Editor) {
	index := editor.selected
	if !editor_delete_step(&editor.run.pipeline.steps, index) do return
	editor_apply_change(editor, {kind = .Delete, index = index})
	editor.selected = min(index, len(editor.run.pipeline.steps) - 1)
	editor.brush.on = false
	editor.panel_row = 0
	editor_edited(editor, index)
}

// On only for a brushable step.
editor_toggle_brush :: proc(editor: ^Editor) {
	if editor.brush.on {
		editor.brush.on = false
		return
	}
	if editor.selected == 0 || !editor_brushable(editor_selected_step(editor)^) {
		editor_set_message(editor, "brush: an assign step painted with strokes")
		return
	}
	editor.brush.on = true
	editor.brush.picked = false
	editor.brush.counted = false
}

editor_save :: proc(editor: ^Editor) {
	text := pipeline.pipeline_save(editor.run.pipeline)
	defer delete(text)
	if error := os.write_entire_file(editor.pipeline_path, text); error != nil {
		editor_set_message(editor, fmt.tprintf("save failed: %v", error))
		return
	}
	editor.unsaved = false
	editor.leave_warned = false
	editor_set_message(editor, "saved")
}

// The radius, the pick under the crosshair, then a paint or an erase at the hit.
editor_brush_step :: proc(editor: ^Editor, input: Editor_Input) {
	brush := &editor.brush
	if !brush.on do return
	brush.radius = clamp(brush.radius * math.pow(EDITOR_BRUSH_RADIUS_FACTOR, input.radius_notches), EDITOR_BRUSH_RADIUS_MINIMUM, EDITOR_BRUSH_RADIUS_MAXIMUM)
	editor_brush_pick(editor)
	step := editor_selected_step(editor)
	if .Paint in input.pressed && brush.hit {
		editor_add_stroke(step, {position = brush.position, radius = brush.radius})
		editor_edited(editor, editor.selected)
	} else if .Erase in input.pressed && brush.hit && editor_erase_stroke_near(step, brush.position, brush.radius) {
		editor_edited(editor, editor.selected)
	}
}

editor_camera :: proc(editor: ^Editor) -> engine.Camera {
	return engine.fly_camera(editor.fly, engine.SCENE_VIEW_VERTICAL_FOV, engine.SCENE_VIEW_NEAR, 100)
}

// The crosshair's ray onto the selected machine's mesh, the step's output
// (an assign moves no vertex, so it lies where its input does), made
// again only when the camera or the step changed. The hit is kept in the
// machine's own frame, where strokes are stored.
editor_brush_pick :: proc(editor: ^Editor) {
	brush := &editor.brush
	step := editor.selected
	key := Editor_Pick_Key{editor.fly, step, editor.generations[step]}
	if brush.picked && brush.pick_key == key do return
	brush.pick_key, brush.picked, brush.hit = key, true, false
	if step == 0 || step >= len(editor.run.outputs) do return
	camera := editor_camera(editor)
	direction := linalg.normalize(camera.target - camera.position)
	origin := camera.position - editor_machine_offset(step)
	brush.position, _, brush.hit = pipeline.ray_pick(editor.run.outputs[step], origin, direction)
}

// The triangles each of the selected step's strokes takes in its input,
// counted again only after a rerun reached the step.
editor_refresh_counts :: proc(editor: ^Editor) {
	brush := &editor.brush
	if !brush.on do return
	step := editor.selected
	key := [2]int{step, editor.generations[step]}
	if brush.counted && brush.counts_key == key do return
	delete(brush.counts)
	brush.counts = nil
	if step == 0 || step - 1 >= len(editor.run.outputs) do return
	brush.counts = pipeline.stroke_triangle_counts(editor.run.outputs[step - 1], editor_selected_step(editor).select.strokes)
	brush.counts_key, brush.counted = key, true
}
