package app

// The level of detail panel of a demo with level items: the dials of
// engine.Lod_Settings moved live by the d-pad or the arrows, a row reset to
// its default by South or Enter, and the triangles and the items per level
// of the frame read back under them.

import "core:fmt"
import "core:math"
import "core:strings"
import engine "../engine"
import rl "shared:raylib"

LOD_PANEL_MARGIN :: 16
LOD_PANEL_PADDING :: 8
LOD_PANEL_PIXELS_MINIMUM :: f32(1)
LOD_PANEL_PIXELS_MAXIMUM :: f32(64)
LOD_PANEL_HYSTERESIS_STEP :: f32(0.05)
LOD_PANEL_HYSTERESIS_MAXIMUM :: f32(0.5)
LOD_PANEL_CROSSFADE_STEP :: f32(0.1)
LOD_PANEL_CROSSFADE_MAXIMUM :: f32(2)

Lod_Panel_Row :: enum {
	Pixels_Per_Triangle,
	Hysteresis,
	Crossfade,
	Tint,
	Freeze,
}

Lod_Panel :: struct {
	open: bool,
	row:  int,
}

// One frame's presses.
Lod_Panel_Input :: struct {
	toggle, up, down, left, right, reset: bool,
}

// Toggling ends the step; a closed panel reads nothing else. The row moves
// first, wrapping at both ends, then the reset, then the adjustment.
lod_panel_step :: proc(panel: ^Lod_Panel, settings: ^engine.Lod_Settings, input: Lod_Panel_Input) {
	if input.toggle {
		panel.open = !panel.open
		return
	}
	if !panel.open do return
	count := len(Lod_Panel_Row)
	panel.row = ((panel.row + int(input.down) - int(input.up)) % count + count) % count
	row := Lod_Panel_Row(panel.row)
	if input.reset do lod_panel_reset(settings, row)
	direction := int(input.right) - int(input.left)
	if direction != 0 do lod_panel_adjust(settings, row, direction)
}

@(private = "file")
lod_panel_reset :: proc(settings: ^engine.Lod_Settings, row: Lod_Panel_Row) {
	default := engine.LOD_SETTINGS_DEFAULT
	switch row {
	case .Pixels_Per_Triangle: settings.pixels_per_triangle = default.pixels_per_triangle
	case .Hysteresis: settings.hysteresis = default.hysteresis
	case .Crossfade: settings.crossfade_seconds = default.crossfade_seconds
	case .Tint: settings.tint = default.tint
	case .Freeze: settings.freeze = default.freeze
	}
}

@(private = "file")
lod_panel_adjust :: proc(settings: ^engine.Lod_Settings, row: Lod_Panel_Row, direction: int) {
	switch row {
	case .Pixels_Per_Triangle:
		factor := math.SQRT_TWO if direction > 0 else 1 / math.SQRT_TWO
		settings.pixels_per_triangle = clamp(settings.pixels_per_triangle * f32(factor), LOD_PANEL_PIXELS_MINIMUM, LOD_PANEL_PIXELS_MAXIMUM)
	case .Hysteresis:
		settings.hysteresis = lod_panel_step_value(settings.hysteresis, LOD_PANEL_HYSTERESIS_STEP, LOD_PANEL_HYSTERESIS_MAXIMUM, direction)
	case .Crossfade:
		settings.crossfade_seconds = lod_panel_step_value(settings.crossfade_seconds, LOD_PANEL_CROSSFADE_STEP, LOD_PANEL_CROSSFADE_MAXIMUM, direction)
	case .Tint: settings.tint = !settings.tint
	case .Freeze: settings.freeze = !settings.freeze
	}
}

// The value moved by one step and rounded to a whole step, so repeated steps
// do not drift, within zero and the maximum.
@(private = "file")
lod_panel_step_value :: proc(value, step, maximum: f32, direction: int) -> f32 {
	return clamp(math.round(value / step + f32(direction)) * step, 0, maximum)
}

lod_panel_row_text :: proc(row: Lod_Panel_Row, settings: engine.Lod_Settings) -> string {
	switch row {
	case .Pixels_Per_Triangle: return fmt.tprintf("Pixels per triangle: %.1f", settings.pixels_per_triangle)
	case .Hysteresis: return fmt.tprintf("Hysteresis: %.2f", settings.hysteresis)
	case .Crossfade: return fmt.tprintf("Crossfade: %.1f s", settings.crossfade_seconds)
	case .Tint: return fmt.tprintf("Tint: %s", "on" if settings.tint else "off")
	case .Freeze: return fmt.tprintf("Freeze: %s", "on" if settings.freeze else "off")
	}
	return ""
}

// The counts at each level up to the last level holding an item.
lod_panel_levels_text :: proc(items_per_level: [8]int) -> string {
	last := -1
	for count, level in items_per_level {
		if count > 0 do last = level
	}
	builder := strings.builder_make(context.temp_allocator)
	strings.write_string(&builder, "Items per level:")
	for level in 0 ..= last do fmt.sbprintf(&builder, " %d", items_per_level[level])
	return strings.to_string(builder)
}

// The lines in reference points of a 720 point high screen, scaled like the
// menu, on one dark translucent plaque at the top left, the selected row
// marked.
lod_panel_draw :: proc(panel: Lod_Panel, view: ^engine.Scene_View) {
	if !panel.open do return
	triangles, items_per_level := engine.scene_view_level_counts(view)
	lines := make([dynamic]string, context.temp_allocator)
	for row in Lod_Panel_Row {
		marker := "> " if int(row) == panel.row else "  "
		append(&lines, fmt.tprintf("%s%s", marker, lod_panel_row_text(row, view.lod)))
	}
	append(&lines, fmt.tprintf("Triangles: %d", triangles))
	append(&lines, lod_panel_levels_text(items_per_level))
	scale := f32(screen_size().y) / MENU_REFERENCE_HEIGHT
	widest := 0
	for line in lines do widest = max(widest, measure_label_text(line))
	height := i32(len(lines)) * LABEL_FONT_SIZE + 2 * LOD_PANEL_PADDING
	plaque := [4]f32{LOD_PANEL_MARGIN, LOD_PANEL_MARGIN, f32(widest + 2 * LOD_PANEL_PADDING), f32(height)} * scale
	rl.DrawRectangle(i32(plaque.x), i32(plaque.y), i32(plaque.z), i32(plaque.w), LABEL_BACKGROUND_COLOR)
	for line, index in lines {
		x := f32(LOD_PANEL_MARGIN + LOD_PANEL_PADDING) * scale
		y := f32(LOD_PANEL_MARGIN + LOD_PANEL_PADDING + i32(index) * LABEL_FONT_SIZE) * scale
		rl.DrawText(strings.clone_to_cstring(line, context.temp_allocator), i32(x), i32(y), i32(f32(LABEL_FONT_SIZE) * scale), TEXT_COLOR)
	}
}

// Whether any item of the view's scene has levels.
lod_panel_available :: proc(view: ^engine.Scene_View) -> bool {
	for levels in view.item_levels {
		if len(levels.mesh_ids) > 0 do return true
	}
	return false
}
