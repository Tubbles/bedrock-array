package app

// The pipeline editor's edits of the steps: strokes painted and erased,
// steps inserted, deleted, moved, enabled and disabled, and a step's keys
// moved by a step size within limits. Each procedure changes only the
// steps it is given; rerunning the pipeline and the views follow in
// editor.odin.

import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import pipeline "../pipeline"

Editor_Key :: enum {
	Front,
	Height,
	Metres,
	Part,
	From_X,
	From_Y,
	From_Z,
	To_X,
	To_Y,
	To_Z,
	Turn,
	Triangles,
	Technique,
	Trim,
}

// The keys the panel offers for each op. The select of assign, delete and
// copy is painted with the brush instead.
EDITOR_OP_KEYS := [pipeline.Op][]Editor_Key {
	.Import    = {},
	.Transform = {.Front, .Height},
	.Weld      = {.Metres},
	.Assign    = {.Part},
	.Delete    = {},
	.Copy      = {.From_X, .From_Y, .From_Z, .To_X, .To_Y, .To_Z, .Turn},
	.Decimate  = {.Triangles},
	.Close     = {.Part, .Technique, .Trim},
}

EDITOR_KEY_NAMES := [Editor_Key]string {
	.Front     = "front",
	.Height    = "height",
	.Metres    = "metres",
	.Part      = "part",
	.From_X    = "from x",
	.From_Y    = "from y",
	.From_Z    = "from z",
	.To_X      = "to x",
	.To_Y      = "to y",
	.To_Z      = "to z",
	.Turn      = "turn",
	.Triangles = "triangles",
	.Technique = "technique",
	.Trim      = "trim",
}

// The ops the insert menu offers, every op but import.
EDITOR_INSERTABLE_OPS := [?]pipeline.Op{.Transform, .Weld, .Assign, .Delete, .Copy, .Decimate, .Close}

// A key's step, in its own unit, and its limits. Metres moves by a factor
// of ten instead.
Editor_Key_Range :: struct {
	step, minimum, maximum: f32,
}

EDITOR_HEIGHT_RANGE :: Editor_Key_Range{0.05, 0.05, 10}
EDITOR_METRES_RANGE :: Editor_Key_Range{10, 1e-7, 1e-2}
EDITOR_POSITION_RANGE :: Editor_Key_Range{0.01, -5, 5}
EDITOR_TRIANGLES_RANGE :: Editor_Key_Range{1000, 1000, 1_000_000}
EDITOR_TRIM_RANGE :: Editor_Key_Range{0.001, 0, 0.05}

// A new step's keys: a step inserted with them runs at once, and a select
// of no strokes takes nothing until the brush paints it. The part is the
// brief's first, or "part" when the brief names none.
editor_default_step :: proc(op: pipeline.Op, parts: []string) -> pipeline.Step {
	step := pipeline.Step{op = op, enabled = true, front = .Plus_X, height = 1, metres = 0.00001, triangles = 12000, trim = 0.003}
	if op == .Assign || op == .Close do step.part = strings.clone(parts[0] if len(parts) > 0 else "part")
	if op == .Assign || op == .Delete || op == .Copy do step.select.kind = .Strokes
	return step
}

// Inserts a step of the op with its default keys after the index and
// returns its index, or -1 for import, which only the first step is.
editor_insert_step :: proc(steps: ^[dynamic]pipeline.Step, after: int, op: pipeline.Op, parts: []string) -> int {
	if op == .Import do return -1
	index := clamp(after + 1, 1, len(steps))
	inject_at(steps, index, editor_default_step(op, parts))
	return index
}

// Removes the step, never the import at index 0. deleted is false when
// nothing was removed.
editor_delete_step :: proc(steps: ^[dynamic]pipeline.Step, index: int) -> (deleted: bool) {
	if index <= 0 || index >= len(steps) do return false
	pipeline.step_destroy(&steps[index])
	ordered_remove(steps, index)
	return true
}

// Swaps the step with its neighbour in the direction's sign, never past
// the import at index 0. Returns the step's new index, its old one when it
// did not move.
editor_move_step :: proc(steps: ^[dynamic]pipeline.Step, index, direction: int) -> int {
	target := index + (1 if direction > 0 else -1)
	if index <= 0 || target <= 0 || target >= len(steps) do return index
	slice.swap(steps[:], index, target)
	return target
}

editor_toggle_step :: proc(step: ^pipeline.Step) {
	step.enabled = !step.enabled
}

// An assign step the brush paints: its select is strokes, or it selects
// no pieces yet, which the first stroke turns into strokes.
editor_brushable :: proc(step: pipeline.Step) -> bool {
	if step.op != .Assign do return false
	return step.select.kind == .Strokes || (step.select.kind == .Pieces && len(step.select.pieces) == 0)
}

editor_add_stroke :: proc(step: ^pipeline.Step, stroke: pipeline.Stroke) {
	if step.select.kind != .Strokes {
		delete(step.select.pieces)
		step.select.pieces = nil
		step.select.kind = .Strokes
	}
	strokes := make([]pipeline.Stroke, len(step.select.strokes) + 1)
	copy(strokes, step.select.strokes)
	strokes[len(strokes) - 1] = stroke
	delete(step.select.strokes)
	step.select.strokes = strokes
}

// Removes the stroke whose centre is nearest the position, if the position
// lies within that stroke's radius plus reach. erased is false otherwise.
editor_erase_stroke_near :: proc(step: ^pipeline.Step, position: [3]f32, reach: f32) -> (erased: bool) {
	nearest, nearest_distance := -1, max(f32)
	for stroke, index in step.select.strokes {
		distance := linalg.length(stroke.position - position)
		if distance <= stroke.radius + reach && distance < nearest_distance do nearest, nearest_distance = index, distance
	}
	if nearest < 0 do return false
	strokes := make([]pipeline.Stroke, len(step.select.strokes) - 1)
	copy(strokes, step.select.strokes[:nearest])
	copy(strokes[nearest:], step.select.strokes[nearest + 1:])
	delete(step.select.strokes)
	step.select.strokes = strokes
	return true
}

// The part after or before the step's in the brief's list, wrapping; the
// first or the last when the step's part is not listed.
editor_cycle_part :: proc(step: ^pipeline.Step, parts: []string, direction: int) {
	if len(parts) == 0 do return
	position, found := slice.linear_search(parts, step.part)
	next := (0 if direction > 0 else len(parts) - 1)
	if found do next = ((position + direction) % len(parts) + len(parts)) % len(parts)
	delete(step.part)
	step.part = strings.clone(parts[next])
}

// The value moved by one step, rounded to a whole step so repeats do not
// drift, within the limits.
editor_step_value :: proc(value: f32, key_range: Editor_Key_Range, direction: int) -> f32 {
	return clamp(math.round(value / key_range.step + f32(direction)) * key_range.step, key_range.minimum, key_range.maximum)
}

editor_cycle :: proc(value, count, direction: int) -> int {
	return ((value + direction) % count + count) % count
}

// Moves the key by one step in the direction's sign.
editor_adjust_key :: proc(step: ^pipeline.Step, key: Editor_Key, direction: int, parts: []string) {
	switch key {
	case .Front: step.front = pipeline.Front(editor_cycle(int(step.front), len(pipeline.Front), direction))
	case .Height: step.height = editor_step_value(step.height, EDITOR_HEIGHT_RANGE, direction)
	case .Metres:
		factor := EDITOR_METRES_RANGE.step if direction > 0 else 1 / EDITOR_METRES_RANGE.step
		step.metres = clamp(step.metres * factor, EDITOR_METRES_RANGE.minimum, EDITOR_METRES_RANGE.maximum)
	case .Part: editor_cycle_part(step, parts, direction)
	case .From_X, .From_Y, .From_Z:
		axis := int(key) - int(Editor_Key.From_X)
		step.from[axis] = editor_step_value(step.from[axis], EDITOR_POSITION_RANGE, direction)
	case .To_X, .To_Y, .To_Z:
		axis := int(key) - int(Editor_Key.To_X)
		step.to[axis] = editor_step_value(step.to[axis], EDITOR_POSITION_RANGE, direction)
	case .Turn: step.turn = editor_cycle(step.turn, 4, direction)
	case .Triangles: step.triangles = int(editor_step_value(f32(step.triangles), EDITOR_TRIANGLES_RANGE, direction))
	case .Technique: step.technique = pipeline.Close_Technique(editor_cycle(int(step.technique), len(pipeline.Close_Technique), direction))
	case .Trim: step.trim = editor_step_value(step.trim, EDITOR_TRIM_RANGE, direction)
	}
}

// Sets the key back to the value a newly inserted step has.
editor_reset_key :: proc(step: ^pipeline.Step, key: Editor_Key, parts: []string) {
	default := editor_default_step(step.op, parts)
	defer pipeline.step_destroy(&default)
	switch key {
	case .Front: step.front = default.front
	case .Height: step.height = default.height
	case .Metres: step.metres = default.metres
	case .Part:
		delete(step.part)
		step.part = strings.clone(default.part)
	case .From_X, .From_Y, .From_Z: step.from[int(key) - int(Editor_Key.From_X)] = 0
	case .To_X, .To_Y, .To_Z: step.to[int(key) - int(Editor_Key.To_X)] = 0
	case .Turn: step.turn = 0
	case .Triangles: step.triangles = default.triangles
	case .Technique: step.technique = default.technique
	case .Trim: step.trim = default.trim
	}
}

Editor_Change_Kind :: enum {
	Insert,
	Delete,
	Swap,
}

// A change of the step list's order: a step inserted at index, deleted
// from index, or swapped between index and other.
Editor_Change :: struct {
	kind:         Editor_Change_Kind,
	index, other: int,
}

// Where a step at index sits after the change, -1 when it was deleted.
editor_index_after :: proc(change: Editor_Change, index: int) -> int {
	switch change.kind {
	case .Insert: return index + 1 if index >= change.index else index
	case .Delete:
		if index == change.index do return -1
		return index - 1 if index > change.index else index
	case .Swap:
		if index == change.index do return change.other
		if index == change.other do return change.index
	}
	return index
}
