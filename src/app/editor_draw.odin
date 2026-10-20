package app

// The pipeline editor's frame: the step views composited into a grid by the
// engine, then the step list, the views' titles and the selected view's
// frame drawn by raylib over them. Rectangles are window pixels from the
// top left; raylib draws in points, so they are divided by the display's
// scale before it draws them.

import "core:fmt"
import "core:strings"
import engine "../engine"
import pipeline "../pipeline"
import rl "shared:raylib"
import rlgl "shared:raylib/rlgl"

EDITOR_LIST_FRACTION :: 4
EDITOR_LIST_PADDING :: 8
EDITOR_ROW_GAP :: 4
EDITOR_FRAME_WIDTH :: 3
EDITOR_FRAME_COLOR :: rl.Color{255, 200, 60, 255}
EDITOR_STATUS_COLOR :: rl.Color{255, 140, 120, 255}
EDITOR_HEADER_LINES :: 2

Editor_Rectangle :: struct {
	x, y, width, height: i32,
}

// The right three quarters of the window, the step list taking the rest.
editor_view_area :: proc(size: [2]i32) -> Editor_Rectangle {
	list_width := size.x / EDITOR_LIST_FRACTION
	return {list_width, 0, size.x - list_width, size.y}
}

// One cell is the whole area, two sit side by side, three and four fill a
// two by two grid in reading order.
editor_grid_cells :: proc(count: int, area: Editor_Rectangle) -> (cells: [EDITOR_VIEWS_MAXIMUM]Editor_Rectangle) {
	columns := i32(1 if count <= 1 else 2)
	rows := i32(1 if count <= 2 else 2)
	width, height := area.width / columns, area.height / rows
	for index in 0 ..< min(count, EDITOR_VIEWS_MAXIMUM) {
		column, row := i32(index) % columns, i32(index) / columns
		cells[index] = {area.x + column * width, area.y + row * height, width, height}
	}
	return
}

// The step's select in a few words.
editor_select_text :: proc(select: pipeline.Select) -> string {
	text: string
	switch select.kind {
	case .Pieces: text = fmt.tprintf("%d %s", len(select.pieces), "piece" if len(select.pieces) == 1 else "pieces")
	case .Part: text = fmt.tprintf("part %s", select.part)
	case .Box: text = "box"
	case .Sphere: text = "sphere"
	case .Strokes: text = fmt.tprintf("%d %s", len(select.strokes), "stroke" if len(select.strokes) == 1 else "strokes")
	}
	if select.within_part != "" do text = fmt.tprintf("%s in %s", text, select.within_part)
	return text
}

// The step's keys besides op, enabled and note.
editor_keys_text :: proc(step: pipeline.Step) -> string {
	switch step.op {
	case .Import: return ""
	case .Transform: return fmt.tprintf("%s, height %v", pipeline.FRONT_NAMES[step.front], step.height)
	case .Weld: return fmt.tprintf("metres %v", step.metres)
	case .Assign: return fmt.tprintf("%s, %s", step.part, editor_select_text(step.select))
	case .Delete: return editor_select_text(step.select)
	case .Copy: return fmt.tprintf("turn %d, %s", step.turn, editor_select_text(step.select))
	case .Decimate: return fmt.tprintf("triangles %d", step.triangles)
	case .Close: return fmt.tprintf("%s, %s, trim %v", step.part, pipeline.TECHNIQUE_NAMES[step.technique], step.trim)
	}
	return ""
}

// The triangle count of a done step, its state otherwise.
editor_result_text :: proc(run: pipeline.Run, index: int) -> string {
	if index < len(run.outputs) do return fmt.tprintf("%d", len(run.outputs[index].triangles))
	switch run.status[index].state {
	case .Stale: return "stale"
	case .Running: return "running"
	case .Done: return "done"
	case .Failed: return "failed"
	}
	return ""
}

// The row's two lines: the index, the op and the result, then the keys or
// the failure. A shown step is marked with an asterisk, a disabled one off.
editor_step_lines :: proc(run: pipeline.Run, index: int, shown: bool) -> (first, second: string) {
	step := run.pipeline.steps[index]
	marker := "*" if shown else " "
	disabled := " off" if !step.enabled else ""
	first = fmt.tprintf("%s%d %s%s  %s", marker, index, pipeline.OP_NAMES[step.op], disabled, editor_result_text(run, index))
	second = editor_keys_text(step)
	if run.status[index].state == .Failed do second = run.status[index].message
	return
}

// The first row drawn, so the selected one stays in view.
editor_first_row :: proc(selected, visible, count: int) -> int {
	return clamp(selected - visible + 1, 0, max(count - visible, 0))
}

@(private = "file")
editor_text :: proc(text: string, x, y: f32, size: f32, color: rl.Color) {
	rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), i32(x), i32(y), i32(size), color)
}

// In reference points of a 720 point high screen, scaled like the menu,
// clipped to the list's column.
editor_draw_list :: proc(editor: ^Editor, screen: [2]i32) {
	scale := f32(screen.y) / MENU_REFERENCE_HEIGHT
	width := screen.x / EDITOR_LIST_FRACTION
	font := f32(LABEL_FONT_SIZE) * scale
	padding := f32(EDITOR_LIST_PADDING) * scale
	row_height := 2 * font + f32(EDITOR_ROW_GAP) * scale
	rl.BeginScissorMode(0, 0, width, screen.y)
	defer rl.EndScissorMode()
	colours := "false colour" if editor.false_colour else "brief materials"
	editor_text(editor.machine, padding, padding, font, TEXT_COLOR)
	editor_text(colours, padding, padding + font, font, TEXT_COLOR)
	top := padding + f32(EDITOR_HEADER_LINES) * font + padding
	count := len(editor.run.pipeline.steps)
	visible := max(int((f32(screen.y) - top) / row_height), 1)
	first := editor_first_row(editor.selected, visible, count)
	for index in first ..< min(first + visible, count) {
		y := top + f32(index - first) * row_height
		if index == editor.selected do rl.DrawRectangle(0, i32(y), width, i32(row_height), MENU_HIGHLIGHT_COLOR)
		shown := false
		for step in editor.shown do shown = shown || step == index
		line, keys := editor_step_lines(editor.run, index, shown)
		failed := editor.run.status[index].state == .Failed
		editor_text(line, padding, y, font, EDITOR_STATUS_COLOR if failed else TEXT_COLOR)
		editor_text(keys, padding + 2 * font, y + font, font, TEXT_COLOR)
	}
}

// A cell in points from a rectangle in pixels.
editor_points :: proc(cell: Editor_Rectangle, pixels_per_point: f32) -> rl.Rectangle {
	return {f32(cell.x) / pixels_per_point, f32(cell.y) / pixels_per_point, f32(cell.width) / pixels_per_point, f32(cell.height) / pixels_per_point}
}

// Each view's step and, while it has no output, the step's state; the
// selected step's view framed.
editor_draw_view_titles :: proc(editor: ^Editor, cells: [EDITOR_VIEWS_MAXIMUM]Editor_Rectangle, pixels_per_point: f32, screen: [2]i32) {
	scale := f32(screen.y) / MENU_REFERENCE_HEIGHT
	font := f32(LABEL_FONT_SIZE) * scale
	padding := f32(EDITOR_LIST_PADDING) * scale
	for upload, index in editor.uploads {
		rectangle := editor_points(cells[index], pixels_per_point)
		step := editor.run.pipeline.steps[upload.step]
		title := fmt.tprintf("%d %s  %s", upload.step, pipeline.OP_NAMES[step.op], editor_result_text(editor.run, upload.step))
		editor_text(title, rectangle.x + padding, rectangle.y + padding, font, TEXT_COLOR)
		if upload.step == editor.selected do rl.DrawRectangleLinesEx(rectangle, f32(EDITOR_FRAME_WIDTH) * scale, EDITOR_FRAME_COLOR)
	}
}

// The views first, through the engine, then raylib's text over them. A
// capture_path names the PNG the frame is written to; written is false
// when that export fails.
draw_editor_frame :: proc(editor: ^Editor, in_shot: bool, capture_path: string) -> (written: bool) {
	size := render_size()
	screen := screen_size()
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)
	cells := editor_grid_cells(len(editor.uploads), editor_view_area(size))
	for upload, index in editor.uploads {
		cell := cells[index]
		editor_fill_draw_list(editor, upload)
		engine.gl_renderer_draw_viewport(&editor.scene.renderer, editor.draw_list, editor.scene.library, cell.x, size.y - cell.y - cell.height, cell.width, cell.height)
	}
	give_state_back_to_rlgl(size)
	pixels_per_point := f32(size.x) / f32(max(screen.x, 1))
	editor_draw_list(editor, screen)
	editor_draw_view_titles(editor, cells, pixels_per_point, screen)
	if !in_shot do rl.DrawText(BUILD_INFO, 16, screen.y - 16 - LABEL_FONT_SIZE, LABEL_FONT_SIZE, TEXT_COLOR)
	written = true
	// raylib draws its batch at EndDrawing, after the capture would read the screen.
	rlgl.DrawRenderBatchActive()
	if capture_path != "" do written = capture_screen(capture_path)
	rl.EndDrawing()
	return written
}

// The mouse turns while its left button is down and the wheel zooms; A and
// D go round, E and Q rise and sink, W and S zoom, as the orbit demos do.
// The pad's right stick turns, its left stick goes round and zooms, and
// its d-pad is left to the step list.
editor_camera_input :: proc(input: ^Editor_Input, snapshot: Gamepad_Snapshot, delta_time: f32) {
	step_time := min(delta_time, engine.SCENE_VIEW_STEP_LIMIT)
	if rl.IsMouseButtonDown(.LEFT) {
		mouse := rl.GetMouseDelta()
		input.turn += [2]f32{mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL
	}
	input.zoom += rl.GetMouseWheelMove() * APP_WHEEL_ZOOM_PER_NOTCH
	pad := gamepad_scene_input(snapshot, step_time)
	walk := keyboard_walk(false, false)
	walk.x += pad.walk.x
	walk.z += pad.walk.z
	input.turn += pad.turn
	input.turn += [2]f32{-walk.x, walk.y} * engine.SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND * step_time
	input.zoom += walk.z * engine.SCENE_VIEW_ZOOM_PER_SECOND * step_time
}
