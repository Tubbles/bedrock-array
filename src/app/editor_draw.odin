package app

// The pipeline editor's frame: the line of machines drawn by the engine
// over the whole window, then by raylib over it a plaque above each
// machine near the camera, the selected machine's bounds as lines, the
// crosshair with the brush's ring, and on the left the header, the step
// list and the key panel or the insert menu. Positions are in points from
// the window's top left, raylib's 2D units.

import "core:fmt"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import engine "../engine"
import pipeline "../pipeline"
import rl "shared:raylib"
import rlgl "shared:raylib/rlgl"

// The overlay on the left takes this fraction of the window's width.
EDITOR_LIST_FRACTION :: 5
EDITOR_LIST_PADDING :: 8
EDITOR_ROW_GAP :: 4
EDITOR_FRAME_WIDTH :: 2
EDITOR_FRAME_COLOR :: rl.Color{255, 200, 60, 255}
EDITOR_STATUS_COLOR :: rl.Color{255, 140, 120, 255}
EDITOR_PLAQUE_SELECTED_COLOR :: rl.Color{60, 50, 20, 210}
EDITOR_HEADER_LINES :: 3
EDITOR_STROKES_PER_LINE :: 3
// Points a plaque's text wraps at, and metres it floats above its machine.
EDITOR_PLAQUE_WIDTH :: 240
EDITOR_PLAQUE_LIFT :: f32(0.08)
EDITOR_CROSSHAIR_SIZE :: f32(8)
// Metres within which a plaque other than the selected one shows every
// line; beyond, only its title, so the plaques down the line stay legible.
EDITOR_PLAQUE_FULL_DISTANCE :: f32(4)

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
	case .Transform: return fmt.tprintf("%s, height %.4g", pipeline.FRONT_NAMES[step.front], step.height)
	case .Weld: return fmt.tprintf("metres %.4g", step.metres)
	case .Assign: return fmt.tprintf("%s, %s", step.part, editor_select_text(step.select))
	case .Delete: return editor_select_text(step.select)
	case .Copy: return fmt.tprintf("turn %d, %s", step.turn, editor_select_text(step.select))
	case .Decimate: return fmt.tprintf("triangles %d", step.triangles)
	case .Close: return fmt.tprintf("%s, %s, trim %.4g", step.part, pipeline.TECHNIQUE_NAMES[step.technique], step.trim)
	}
	return ""
}

// The triangle count of a done step, its state otherwise.
editor_result_text :: proc(run: pipeline.Run, index: int) -> string {
	if index < len(run.outputs) do return fmt.tprintf("%d", len(run.outputs[index].triangles))
	return editor_state_text(run.status[index].state)
}

editor_state_text :: proc(state: pipeline.Step_State) -> string {
	switch state {
	case .Stale: return "stale"
	case .Running: return "computing"
	case .Done: return "done"
	case .Failed: return "failed"
	}
	return ""
}

// The row's two lines: the index, the op and the result, then the keys or
// the failure. A disabled step is marked off.
editor_step_lines :: proc(run: pipeline.Run, index: int) -> (first, second: string) {
	step := run.pipeline.steps[index]
	disabled := " off" if !step.enabled else ""
	first = fmt.tprintf("%d %s%s  %s", index, pipeline.OP_NAMES[step.op], disabled, editor_result_text(run, index))
	second = editor_keys_text(step)
	if run.status[index].state == .Failed do second = run.status[index].message
	return
}

// A machine's plaque: the step's number and op, its keys, its triangles
// and its state, with the failure's message.
editor_plaque_lines :: proc(run: pipeline.Run, index: int) -> []string {
	lines := make([dynamic]string, context.temp_allocator)
	step := run.pipeline.steps[index]
	append(&lines, fmt.tprintf("%d %s%s", index, pipeline.OP_NAMES[step.op], " off" if !step.enabled else ""))
	if keys := editor_keys_text(step); keys != "" do append(&lines, keys)
	if index < len(run.outputs) do append(&lines, fmt.tprintf("%d triangles", len(run.outputs[index].triangles)))
	status := run.status[index]
	state := editor_state_text(status.state)
	append(&lines, fmt.tprintf("%s: %s", state, status.message) if status.state == .Failed else state)
	return lines[:]
}

// The first row drawn, so the selected one stays in view.
editor_first_row :: proc(selected, visible, count: int) -> int {
	return clamp(selected - visible + 1, 0, max(count - visible, 0))
}

@(private = "file")
editor_text :: proc(text: string, x, y: f32, size: f32, color: rl.Color) {
	rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), i32(x), i32(y), i32(size), color)
}

// The value of one key as the panel shows it.
editor_key_text :: proc(step: pipeline.Step, key: Editor_Key) -> string {
	value: string
	switch key {
	case .Front: value = pipeline.FRONT_NAMES[step.front]
	case .Height: value = fmt.tprintf("%.2f m", step.height)
	case .Metres: value = fmt.tprintf("%.4g m", step.metres)
	case .Part: value = step.part
	case .From_X, .From_Y, .From_Z: value = fmt.tprintf("%.2f m", step.from[int(key) - int(Editor_Key.From_X)])
	case .To_X, .To_Y, .To_Z: value = fmt.tprintf("%.2f m", step.to[int(key) - int(Editor_Key.To_X)])
	case .Turn: value = fmt.tprintf("%d", step.turn)
	case .Triangles: value = fmt.tprintf("%d", step.triangles)
	case .Technique: value = pipeline.TECHNIQUE_NAMES[step.technique]
	case .Trim: value = fmt.tprintf("%.3f m", step.trim)
	}
	return fmt.tprintf("%s %s", EDITOR_KEY_NAMES[key], value)
}

// The triangles each stroke takes, three strokes to a line.
editor_stroke_lines :: proc(counts: []int) -> []string {
	lines := make([dynamic]string, context.temp_allocator)
	for start := 0; start < len(counts); start += EDITOR_STROKES_PER_LINE {
		line := ""
		for index in start ..< min(start + EDITOR_STROKES_PER_LINE, len(counts)) {
			line = fmt.tprintf("%s%s#%d %d", line, "  " if index > start else "", index, counts[index])
		}
		append(&lines, line)
	}
	return lines[:]
}

// The key panel's or the insert menu's lines, the chosen row marked, none
// while both are closed.
editor_footer_lines :: proc(editor: ^Editor) -> []string {
	lines := make([dynamic]string, context.temp_allocator)
	if editor.op_menu_open {
		append(&lines, fmt.tprintf("insert after %d", editor.selected))
		for op, index in EDITOR_INSERTABLE_OPS {
			append(&lines, fmt.tprintf("%s%s", "> " if index == editor.op_menu_row else "  ", pipeline.OP_NAMES[op]))
		}
	} else if editor.panel_open {
		step := editor.run.pipeline.steps[editor.selected]
		keys := EDITOR_OP_KEYS[step.op]
		append(&lines, fmt.tprintf("keys of %d %s", editor.selected, pipeline.OP_NAMES[step.op]))
		if len(keys) == 0 do append(&lines, "  none to change")
		for key, index in keys {
			append(&lines, fmt.tprintf("%s%s", "> " if index == editor.panel_row else "  ", editor_key_text(step, key)))
		}
	}
	return lines[:]
}

// The header's third line: the message, else the brush's radius and part.
editor_status_line :: proc(editor: ^Editor) -> string {
	if editor.message != "" do return editor.message
	if !editor.brush.on do return ""
	return fmt.tprintf("brush %.0f mm, part %s", editor.brush.radius * 1000, editor.run.pipeline.steps[editor.selected].part)
}

// In reference points of a 720 point high screen, scaled like the menu,
// clipped to the overlay's column on a dark plaque: the header, the step
// rows while the list is open, the panel or the insert menu at the bottom.
editor_draw_overlay :: proc(editor: ^Editor, screen: [2]i32) {
	scale := f32(screen.y) / MENU_REFERENCE_HEIGHT
	width := screen.x / EDITOR_LIST_FRACTION
	font := f32(LABEL_FONT_SIZE) * scale
	padding := f32(EDITOR_LIST_PADDING) * scale
	row_height := 2 * font + f32(EDITOR_ROW_GAP) * scale
	rl.BeginScissorMode(0, 0, width, screen.y)
	defer rl.EndScissorMode()
	top := padding + f32(EDITOR_HEADER_LINES) * font + padding
	footer := editor_footer_lines(editor)
	footer_height := f32(len(footer)) * font + (2 * padding if len(footer) > 0 else 0)
	rl.DrawRectangle(0, 0, width, i32(f32(screen.y) - footer_height) if editor.list_open else i32(top), LABEL_BACKGROUND_COLOR)
	colours := "false colour" if editor.false_colour else "brief materials"
	editor_text(fmt.tprintf("%s%s", editor.machine, "  unsaved" if editor.unsaved else ""), padding, padding, font, TEXT_COLOR)
	editor_text(colours, padding, padding + font, font, TEXT_COLOR)
	editor_text(editor_status_line(editor), padding, padding + 2 * font, font, EDITOR_STATUS_COLOR)
	if editor.list_open do editor_draw_rows(editor, top, f32(screen.y) - footer_height, width, font, padding, row_height)
	if len(footer) == 0 do return
	footer_top := f32(screen.y) - footer_height
	rl.DrawRectangle(0, i32(footer_top), width, i32(footer_height), LABEL_BACKGROUND_COLOR)
	for line, index in footer do editor_text(line, padding, footer_top + padding + f32(index) * font, font, TEXT_COLOR)
}

// The step rows between top and bottom, the selected one highlighted and in view.
@(private = "file")
editor_draw_rows :: proc(editor: ^Editor, top, bottom: f32, width: i32, font, padding, row_height: f32) {
	count := len(editor.run.pipeline.steps)
	visible := max(int((bottom - top) / row_height), 1)
	first := editor_first_row(editor.selected, visible, count)
	y := top
	for index in first ..< min(first + visible, count) {
		if index == editor.selected do rl.DrawRectangle(0, i32(y), width, i32(row_height), MENU_HIGHLIGHT_COLOR)
		line, keys := editor_step_lines(editor.run, index)
		failed := editor.run.status[index].state == .Failed
		editor_text(line, padding, y, font, EDITOR_STATUS_COLOR if failed else TEXT_COLOR)
		editor_text(keys, padding + 2 * font, y + font, font, TEXT_COLOR)
		y += row_height
	}
}

// The canvas point of a world point, from the top left with y down, and
// whether it lies in front of the camera's near plane. Unlike
// world_to_screen it keeps a point off the canvas, so an edge leaving the
// view is still drawn.
editor_project :: proc(camera: engine.Camera, canvas: [2]f32, world: [3]f32) -> (point: [2]f32, in_front: bool) {
	aspect := canvas.x / max(canvas.y, 1)
	clip := engine.projection_matrix(camera, aspect) * engine.view_matrix(camera) * [4]f32{world.x, world.y, world.z, 1}
	if clip.w <= camera.near do return {}, false
	normalised := clip.xy / clip.w
	return {(normalised.x + 1) / 2 * canvas.x, (1 - normalised.y) / 2 * canvas.y}, true
}

// The plaques of the machines within upload range, the farthest first so
// a nearer one covers it, the selected one last and highlighted, those
// farther than EDITOR_PLAQUE_FULL_DISTANCE with their title alone (and
// the state of a step not done).
editor_draw_plaques :: proc(editor: ^Editor, camera: engine.Camera, canvas: [2]f32) {
	Plaque :: struct {
		index:    int,
		distance: f32,
	}
	plaques := make([dynamic]Plaque, context.temp_allocator)
	for machine, index in editor.machines {
		distance := linalg.length(editor_plaque_anchor(machine.bounds, index) - camera.position)
		if index != editor.selected && distance > EDITOR_UPLOAD_DISTANCE do continue
		append(&plaques, Plaque{index, -1 if index == editor.selected else distance})
	}
	slice.sort_by(plaques[:], proc(first, second: Plaque) -> bool {return first.distance > second.distance})
	for plaque in plaques {
		point, in_front := editor_project(camera, canvas, editor_plaque_anchor(editor.machines[plaque.index].bounds, plaque.index))
		if !in_front do continue
		lines := editor_plaque_lines(editor.run, plaque.index)
		selected := plaque.index == editor.selected
		if !selected && plaque.distance > EDITOR_PLAQUE_FULL_DISTANCE do lines = editor_plaque_title(lines, editor.run.status[plaque.index].state)
		if selected && editor.brush.on {
			all := make([dynamic]string, context.temp_allocator)
			append(&all, ..lines)
			append(&all, ..editor_stroke_lines(editor.brush.counts))
			lines = all[:]
		}
		editor_draw_plaque(lines, point, selected, canvas)
	}
}

// A far plaque's lines: the title, and the state while it is not done.
editor_plaque_title :: proc(lines: []string, state: pipeline.Step_State) -> []string {
	if state == .Done do return lines[:1]
	title := make([]string, 2, context.temp_allocator)
	title[0], title[1] = lines[0], lines[len(lines) - 1]
	return title
}

// Above the middle of the machine's top.
editor_plaque_anchor :: proc(bounds: Editor_Bounds, index: int) -> [3]f32 {
	world := editor_world_bounds(bounds, index)
	return {(world.minimum.x + world.maximum.x) / 2, world.maximum.y + EDITOR_PLAQUE_LIFT, (world.minimum.z + world.maximum.z) / 2}
}

// The lines wrapped, each centred on the point's x, the block's bottom at
// the point, on a dark plaque, the selected one's tinted, framed and kept
// within the canvas, so its strokes' counts show while the camera is
// close under its top.
editor_draw_plaque :: proc(lines: []string, given_point: [2]f32, selected: bool, canvas: [2]f32) {
	wrapped := make([dynamic]string, context.temp_allocator)
	for line in lines do append(&wrapped, ..wrap_words(line, EDITOR_PLAQUE_WIDTH, measure_label_text))
	widest := 0
	for line in wrapped do widest = max(widest, measure_label_text(line))
	point := given_point
	if selected {
		margin := f32(2 * LABEL_PADDING)
		half_width := f32(widest) / 2 + margin
		point.x = clamp(point.x, half_width, max(canvas.x - half_width, half_width))
		point.y = clamp(point.y, f32(len(wrapped) * LABEL_FONT_SIZE) + margin, max(canvas.y - margin, margin))
	}
	top := i32(point.y) - i32(len(wrapped)) * LABEL_FONT_SIZE
	left := i32(point.x) - i32(widest) / 2
	plaque := rl.Rectangle{f32(left - LABEL_PADDING), f32(top - LABEL_PADDING), f32(i32(widest) + 2 * LABEL_PADDING), f32(i32(len(wrapped)) * LABEL_FONT_SIZE + 2 * LABEL_PADDING)}
	rl.DrawRectangleRec(plaque, EDITOR_PLAQUE_SELECTED_COLOR if selected else LABEL_BACKGROUND_COLOR)
	if selected do rl.DrawRectangleLinesEx(plaque, EDITOR_FRAME_WIDTH, EDITOR_FRAME_COLOR)
	for line, index in wrapped {
		x := i32(point.x) - i32(measure_label_text(line)) / 2
		y := top + i32(index) * LABEL_FONT_SIZE
		rl.DrawText(strings.clone_to_cstring(line, context.temp_allocator), x, y, LABEL_FONT_SIZE, LABEL_TEXT_COLOR)
	}
}

// The twelve edges of the selected machine's bounds, each edge with an end
// behind the camera left out.
editor_draw_selected_bounds :: proc(editor: ^Editor, camera: engine.Camera, canvas: [2]f32) {
	if editor.selected >= len(editor.machines) do return
	box := editor_world_bounds(editor.machines[editor.selected].bounds, editor.selected)
	corners: [8][3]f32
	for &corner, index in corners {
		for axis in 0 ..< 3 do corner[axis] = box.maximum[axis] if index & (1 << uint(axis)) != 0 else box.minimum[axis]
	}
	for first in 0 ..< 8 {
		for axis in 0 ..< 3 {
			if first & (1 << uint(axis)) != 0 do continue
			start, start_in_front := editor_project(camera, canvas, corners[first])
			end, end_in_front := editor_project(camera, canvas, corners[first | (1 << uint(axis))])
			if start_in_front && end_in_front do rl.DrawLineEx(start, end, EDITOR_FRAME_WIDTH, EDITOR_FRAME_COLOR)
		}
	}
}

// A cross at the window's middle, and in brush mode a ring of the brush's
// radius round the hit.
editor_draw_crosshair :: proc(editor: ^Editor, camera: engine.Camera, canvas: [2]f32) {
	centre := canvas / 2
	size := EDITOR_CROSSHAIR_SIZE
	rl.DrawLineV({centre.x - size, centre.y}, {centre.x + size, centre.y}, EDITOR_FRAME_COLOR)
	rl.DrawLineV({centre.x, centre.y - size}, {centre.x, centre.y + size}, EDITOR_FRAME_COLOR)
	brush := editor.brush
	if !brush.on || !brush.hit do return
	world := brush.position + editor_machine_offset(editor.selected)
	hit, visible := editor_project(camera, canvas, world)
	if !visible do return
	right := linalg.normalize(linalg.cross(camera.target - camera.position, camera.up))
	edge, _ := editor_project(camera, canvas, world + right * brush.radius)
	rl.DrawCircleLinesV(hit, max(linalg.length(edge - hit), 2), EDITOR_FRAME_COLOR)
}

// The line first, through the engine, then raylib's plaques, lines and
// text over it. A capture_path names the PNG the frame is written to;
// written is false when that export fails.
draw_editor_frame :: proc(editor: ^Editor, in_shot: bool, capture_path: string) -> (written: bool) {
	size := render_size()
	screen := screen_size()
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)
	editor_fill_draw_list(editor)
	engine.gl_renderer_draw_viewport(&editor.scene.renderer, editor.draw_list, editor.scene.library, 0, 0, size.x, size.y)
	give_state_back_to_rlgl(size)
	camera := editor_camera(editor)
	canvas := [2]f32{f32(screen.x), f32(screen.y)}
	editor_draw_selected_bounds(editor, camera, canvas)
	editor_draw_plaques(editor, camera, canvas)
	editor_draw_crosshair(editor, camera, canvas)
	editor_draw_overlay(editor, screen)
	if !in_shot do rl.DrawText(BUILD_INFO, 16, screen.y - 16 - LABEL_FONT_SIZE, LABEL_FONT_SIZE, TEXT_COLOR)
	written = true
	// raylib draws its batch at EndDrawing, after the capture would read the screen.
	rlgl.DrawRenderBatchActive()
	if capture_path != "" do written = capture_screen(capture_path)
	rl.EndDrawing()
	return written
}
