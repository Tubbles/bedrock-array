package app

// The pipeline editor's frame step: the selection, the key panel, the
// insert menu, the brush and the commands read from one frame's input,
// each edit marking the editor unsaved and rerunning from the step it
// changed.

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:slice"
import engine "../engine"
import pipeline "../pipeline"

EDITOR_BRUSH_RADIUS_DEFAULT :: f32(0.01)
EDITOR_BRUSH_RADIUS_MINIMUM :: f32(0.002)
EDITOR_BRUSH_RADIUS_MAXIMUM :: f32(0.05)
// The radius is scaled by this per wheel notch or shoulder press.
EDITOR_BRUSH_RADIUS_FACTOR :: f32(1.25)
EDITOR_LEAVE_WARNING :: "unsaved: leave again to discard, S to save"

// What the brush's last pick was made from, so it is made again only
// when one of them changes.
Editor_Pick_Key :: struct {
	cursor:     [2]f32,
	orbit:      engine.Orbit,
	window:     [2]i32,
	step:       int,
	generation: int,
	views:      int,
}

// The brush paints strokes on the selected step, picking its input mesh
// under the cursor. cursor is in points from the window's top left, counts
// the triangles each stroke takes, as of counts_key.
Editor_Brush :: struct {
	on:         bool,
	radius:     f32,
	cursor:     [2]f32,
	hit:        bool,
	position:   [3]f32,
	pick_key:   Editor_Pick_Key,
	picked:     bool,
	counts:     []int,
	counts_key: [2]int,
	counted:    bool,
}

// One frame's presses. turn is in radians and zoom as orbit_zoom takes it,
// both scaled by the frame time. cursor is the mouse in points, taken
// when cursor_set; cursor_move is the stick's movement in points. window
// is the window in pixels and pixels_per_point the display's scale.
Editor_Input :: struct {
	up, down, left, right, confirm:      bool,
	move_up, move_down:                  bool,
	add, drop, toggle_colour:            bool,
	panel, insert_menu, delete, enable:  bool,
	save, brush, cycle_part, leave:      bool,
	paint, erase:                        bool,
	radius_notches:                      f32,
	cursor:                              [2]f32,
	cursor_set:                          bool,
	cursor_move:                         [2]f32,
	turn:                                [2]f32,
	zoom:                                f32,
	window:                              [2]i32,
	pixels_per_point:                    f32,
}

Editor_Command :: enum {
	None,
	Leave,
}

// A leave closes the insert menu, the panel or the brush first. With
// unsaved edits the first leave warns, the next one leaves.
editor_step :: proc(editor: ^Editor, input: Editor_Input) -> Editor_Command {
	if input.leave && editor_leave(editor) do return .Leave
	if editor.op_menu_open {
		editor_op_menu_step(editor, input)
	} else {
		if editor.panel_open do editor_panel_step(editor, input)
		else do editor_selection_step(editor, input)
		editor_command_step(editor, input)
		editor_brush_step(editor, input)
	}
	editor.orbit = engine.orbit_turn(editor.orbit, input.turn, 1)
	editor.orbit = engine.orbit_zoom(editor.orbit, input.zoom, engine.SCENE_VIEW_DISTANCE_MINIMUM, engine.SCENE_VIEW_DISTANCE_MAXIMUM)
	pipeline.run_poll(&editor.run)
	editor_sync_uploads(editor)
	editor_refresh_uploads(editor)
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

// The selection and the grid follow a change of the steps' order. Views
// of a deleted step are dropped.
editor_apply_change :: proc(editor: ^Editor, change: Editor_Change) {
	editor.selected = max(editor_index_after(change, editor.selected), 0)
	kept := 0
	for step in editor.shown {
		after := editor_index_after(change, step)
		if after < 0 do continue
		editor.shown[kept] = after
		kept += 1
	}
	resize(&editor.shown, kept)
	slice.sort(editor.shown[:])
	for &upload in editor.uploads {
		upload.step = editor_index_after(change, upload.step)
		if upload.step >= 0 do continue
		editor_release_upload(editor, &upload)
		delete(upload.meshes)
	}
}

editor_selected_step :: proc(editor: ^Editor) -> ^pipeline.Step {
	return &editor.run.pipeline.steps[editor.selected]
}

// Up and down move the selection, wrapping; with Alt they move the step.
// A new selection closes the brush and starts the panel at its first row.
editor_selection_step :: proc(editor: ^Editor, input: Editor_Input) {
	count := len(editor.run.pipeline.steps)
	if count == 0 do return
	before := editor.selected
	if input.move_up || input.move_down {
		moved := editor_move_step(&editor.run.pipeline.steps, editor.selected, int(input.move_down) - int(input.move_up))
		if moved != before {
			editor_apply_change(editor, {kind = .Swap, index = before, other = moved})
			editor_edited(editor, min(before, moved))
		}
	} else {
		movement := int(input.down) - int(input.up)
		editor.selected = ((editor.selected + movement) % count + count) % count
	}
	if editor.selected != before {
		editor.brush.on = false
		editor.panel_row = 0
	}
}

// Up and down choose the key, left and right change it, Enter resets it.
editor_panel_step :: proc(editor: ^Editor, input: Editor_Input) {
	step := editor_selected_step(editor)
	keys := EDITOR_OP_KEYS[step.op]
	if len(keys) == 0 do return
	editor.panel_row = editor_cycle(editor.panel_row, len(keys), int(input.down) - int(input.up))
	key := keys[editor.panel_row]
	direction := int(input.right) - int(input.left)
	if input.confirm do editor_reset_key(step, key, editor_part_names(editor))
	else if direction != 0 do editor_adjust_key(step, key, direction, editor_part_names(editor))
	if input.confirm || direction != 0 do editor_edited(editor, editor.selected)
}

// Up and down choose the op, Enter inserts it after the selected step and
// selects it, the menu's key closes it.
editor_op_menu_step :: proc(editor: ^Editor, input: Editor_Input) {
	if input.insert_menu {
		editor.op_menu_open = false
		return
	}
	editor.op_menu_row = editor_cycle(editor.op_menu_row, len(EDITOR_INSERTABLE_OPS), int(input.down) - int(input.up))
	if !input.confirm do return
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
	if input.add do editor_shown_add(&editor.shown, editor.selected)
	if input.drop do editor_shown_drop(&editor.shown, editor.selected)
	if input.toggle_colour do editor.false_colour = !editor.false_colour
	if input.panel {
		editor.panel_open = !editor.panel_open
		editor.panel_row = 0
	}
	if input.insert_menu {
		editor.op_menu_open = true
		editor.panel_open = false
	}
	if input.enable && editor.selected > 0 {
		editor_toggle_step(editor_selected_step(editor))
		editor_edited(editor, editor.selected)
	}
	if input.cycle_part {
		step := editor_selected_step(editor)
		if step.op == .Assign || step.op == .Close {
			editor_cycle_part(step, editor_part_names(editor), 1)
			editor_edited(editor, editor.selected)
		}
	}
	if input.delete do editor_delete_selected(editor)
	if input.brush do editor_toggle_brush(editor)
	if input.save do editor_save(editor)
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

// On only for a brushable step, which joins the grid in place of the last
// view when the grid is full.
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
	if !slice.contains(editor.shown[:], editor.selected) {
		if len(editor.shown) >= EDITOR_VIEWS_MAXIMUM do pop(&editor.shown)
		editor_shown_add(&editor.shown, editor.selected)
	}
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

// The radius, the cursor, the pick under it, then a paint or an erase at the hit.
editor_brush_step :: proc(editor: ^Editor, input: Editor_Input) {
	brush := &editor.brush
	if !brush.on do return
	brush.radius = clamp(brush.radius * math.pow(EDITOR_BRUSH_RADIUS_FACTOR, input.radius_notches), EDITOR_BRUSH_RADIUS_MINIMUM, EDITOR_BRUSH_RADIUS_MAXIMUM)
	if input.cursor_set do brush.cursor = input.cursor
	points := [2]f32{f32(input.window.x), f32(input.window.y)} / max(input.pixels_per_point, 1e-3)
	brush.cursor = linalg.clamp(brush.cursor + input.cursor_move, [2]f32{0, 0}, points)
	editor_brush_pick(editor, input.window, input.pixels_per_point)
	step := editor_selected_step(editor)
	if input.paint && brush.hit {
		editor_add_stroke(step, {position = brush.position, radius = brush.radius})
		editor_edited(editor, editor.selected)
	} else if input.erase && brush.hit && editor_erase_stroke_near(step, brush.position, brush.radius) {
		editor_edited(editor, editor.selected)
	}
}

// The view slot showing the step, -1 when none does.
editor_view_of_step :: proc(editor: ^Editor, step: int) -> int {
	for upload, index in editor.uploads {
		if upload.step == step do return index
	}
	return -1
}

editor_camera :: proc(editor: ^Editor) -> engine.Camera {
	return engine.orbit_camera(editor.orbit, engine.SCENE_VIEW_VERTICAL_FOV, engine.SCENE_VIEW_NEAR, 100)
}

// The cursor's ray through the selected step's view onto the step's input
// mesh, made again only when what it depends on changed.
editor_brush_pick :: proc(editor: ^Editor, window: [2]i32, pixels_per_point: f32) {
	brush := &editor.brush
	step := editor.selected
	key := Editor_Pick_Key{brush.cursor, editor.orbit, window, step, editor.generations[step], len(editor.uploads)}
	if brush.picked && brush.pick_key == key do return
	brush.pick_key, brush.picked, brush.hit = key, true, false
	slot := editor_view_of_step(editor, step)
	if slot < 0 || step == 0 || step - 1 >= len(editor.run.outputs) do return
	cell := editor_grid_cells(len(editor.uploads), editor_view_area(window))[slot]
	origin, direction, inside := editor_cursor_ray(editor_camera(editor), cell, brush.cursor * pixels_per_point)
	if !inside do return
	brush.position, _, brush.hit = pipeline.ray_pick(editor.run.outputs[step - 1], origin, direction)
}

// The camera's ray through a pixel of the cell it is drawn into, pixels
// from the window's top left. inside is false for a pixel outside the cell.
editor_cursor_ray :: proc(camera: engine.Camera, cell: Editor_Rectangle, pixel: [2]f32) -> (origin, direction: [3]f32, inside: bool) {
	local := (pixel - [2]f32{f32(cell.x), f32(cell.y)}) / [2]f32{f32(max(cell.width, 1)), f32(max(cell.height, 1))}
	if local.x < 0 || local.y < 0 || local.x > 1 || local.y > 1 do return
	forward := linalg.normalize(camera.target - camera.position)
	right := linalg.normalize(linalg.cross(forward, camera.up))
	up := linalg.cross(right, forward)
	half_height := math.tan(camera.vertical_fov_radians / 2)
	half_width := half_height * f32(cell.width) / f32(max(cell.height, 1))
	ndc := [2]f32{2 * local.x - 1, 1 - 2 * local.y}
	direction = linalg.normalize(forward + right * ndc.x * half_width + up * ndc.y * half_height)
	return camera.position, direction, true
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
