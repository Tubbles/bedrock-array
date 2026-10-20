package app

// The demo menu: the list of demos the app starts on, moved with the d-pad,
// the left stick or the arrow keys, entered with South or Enter and left
// with East or Escape.

import "core:strings"
import rl "shared:raylib"

MENU_STICK_THRESHOLD :: f32(0.5)
// The menu is laid out in points of a 720 point high screen and scaled.
MENU_REFERENCE_HEIGHT :: f32(720)
MENU_MARGIN :: 48
MENU_TITLE_SIZE :: 40
// Integer multiples of raylib's 10 px font at 720p and 1080p, so the glyphs stay crisp.
MENU_NAME_SIZE :: 30
MENU_ROW_GAP :: 16
MENU_ROW_PADDING :: 8
MENU_HIGHLIGHT_COLOR :: rl.Color{70, 70, 90, 255}
MENU_GLYPH_LINE :: "A enter, B quit"

App_Screen :: enum {
	Menu,
	Demo,
	Editor,
}

Menu_State :: struct {
	row: int,
}

Menu_Input :: struct {
	up, down, select, back: bool,
}

Menu_Command :: enum {
	None,
	Enter,
	Leave,
}

// The buttons and the stick as they were on the previous poll.
Menu_Edge_State :: struct {
	buttons:   bit_set[Gamepad_Button],
	stick_out: bool,
}

// The row moves first, wrapping at both ends, then the command is read.
menu_step :: proc(state: ^Menu_State, count: int, input: Menu_Input) -> Menu_Command {
	if count > 0 {
		movement := int(input.down) - int(input.up)
		state.row = ((state.row + movement) % count + count) % count
	}
	if input.select do return .Enter
	if input.back do return .Leave
	return .None
}

// A button counts on the poll it appears in, the stick once each time it
// leaves the middle band.
menu_edges :: proc(state: ^Menu_Edge_State, snapshot: Gamepad_Snapshot) -> Menu_Input {
	pressed := snapshot.buttons - state.buttons
	stick := snapshot.left.y
	stick_out := abs(stick) > MENU_STICK_THRESHOLD
	stick_moved := stick_out && !state.stick_out
	state.buttons = snapshot.buttons
	state.stick_out = stick_out
	return {
		up = .Dpad_Up in pressed || (stick_moved && stick < 0),
		down = .Dpad_Down in pressed || (stick_moved && stick > 0),
		select = .South in pressed,
		back = .East in pressed,
	}
}

menu_input_merge :: proc(first, second: Menu_Input) -> Menu_Input {
	return {
		up = first.up || second.up,
		down = first.down || second.down,
		select = first.select || second.select,
		back = first.back || second.back,
	}
}

@(private = "file")
draw_scaled_text :: proc(text: string, x, y, size: i32, scale: f32, color: rl.Color) {
	scaled := i32(f32(size) * scale)
	rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), i32(f32(x) * scale), i32(f32(y) * scale), scaled, color)
}

// The text up to and including its first full stop, or all of it.
first_sentence :: proc(text: string) -> string {
	for index in 0 ..< len(text) {
		if text[index] == '.' && (index + 1 == len(text) || text[index + 1] == ' ' || text[index + 1] == '\n') {
			return text[:index + 1]
		}
	}
	return text
}

// The description's first sentence, wrapped to the width in reference points:
// the rest of a description is the page's mouse and keyboard hints.
@(private = "file")
menu_row_lines :: proc(demo: Demo, width: i32) -> []string {
	return wrap_words(first_sentence(strings.trim_space(demo.description)), int(width), measure_label_text)
}

// How far the rows move up so the selected row ends above bottom, the rows
// starting at top with heights each followed by MENU_ROW_GAP.
menu_scroll :: proc(heights: []i32, selected: int, top, bottom: i32) -> i32 {
	end := top
	for height in heights[:min(selected + 1, len(heights))] do end += height + MENU_ROW_GAP
	return max(end - MENU_ROW_GAP - bottom, 0)
}

// The descriptions are wrapped with the label measure at LABEL_FONT_SIZE in
// reference points, which scales with the text. The rows scroll to keep the
// selected one above the glyph line and are clipped to the space between
// the title and that line.
menu_draw :: proc(state: Menu_State, demos: []Demo, stamp: string) {
	screen := screen_size()
	scale := f32(screen.y) / MENU_REFERENCE_HEIGHT
	width := i32(f32(screen.x) / scale) - 2 * MENU_MARGIN
	draw_scaled_text("Bedrock Array", MENU_MARGIN, MENU_MARGIN, MENU_TITLE_SIZE, scale, TEXT_COLOR)
	top := i32(MENU_MARGIN + MENU_TITLE_SIZE + 2 * MENU_ROW_GAP)
	rows_bottom := i32(MENU_REFERENCE_HEIGHT) - MENU_MARGIN / 2 - LABEL_FONT_SIZE - MENU_ROW_GAP
	row_lines := make([][]string, len(demos), context.temp_allocator)
	heights := make([]i32, len(demos), context.temp_allocator)
	for demo, index in demos {
		row_lines[index] = menu_row_lines(demo, width - 2 * MENU_ROW_PADDING)
		heights[index] = MENU_NAME_SIZE + i32(len(row_lines[index])) * LABEL_FONT_SIZE + 2 * MENU_ROW_PADDING
	}
	y := top - menu_scroll(heights, state.row, top, rows_bottom)
	rl.BeginScissorMode(0, i32(f32(top) * scale), screen.x, i32(f32(rows_bottom - top) * scale))
	for demo, index in demos {
		lines := row_lines[index]
		height := heights[index]
		if index == state.row {
			rl.DrawRectangle(i32(f32(MENU_MARGIN) * scale), i32(f32(y) * scale), i32(f32(width) * scale), i32(f32(height) * scale), MENU_HIGHLIGHT_COLOR)
		}
		left := i32(MENU_MARGIN + MENU_ROW_PADDING)
		draw_scaled_text(demo.name, left, y + MENU_ROW_PADDING, MENU_NAME_SIZE, scale, TEXT_COLOR)
		for line, line_index in lines {
			draw_scaled_text(line, left, y + MENU_ROW_PADDING + MENU_NAME_SIZE + i32(line_index) * LABEL_FONT_SIZE, LABEL_FONT_SIZE, scale, TEXT_COLOR)
		}
		y += height + MENU_ROW_GAP
	}
	rl.EndScissorMode()
	bottom := i32(MENU_REFERENCE_HEIGHT) - MENU_MARGIN / 2 - LABEL_FONT_SIZE
	draw_scaled_text(MENU_GLYPH_LINE, MENU_MARGIN, bottom, LABEL_FONT_SIZE, scale, TEXT_COLOR)
	stamp_width := measure_label_text(stamp)
	draw_scaled_text(stamp, i32(f32(screen.x) / scale) - MENU_MARGIN - i32(stamp_width), bottom, LABEL_FONT_SIZE, scale, TEXT_COLOR)
}
