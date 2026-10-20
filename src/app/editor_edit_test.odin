#+build !js
package app

import "core:math"
import "core:testing"
import pipeline "../pipeline"

@(private = "file")
test_parts := []string{"skirt", "body", "lid"}

// import, weld, assign body.
@(private = "file")
test_steps :: proc() -> (steps: [dynamic]pipeline.Step) {
	append(&steps, editor_default_step(.Import, test_parts))
	append(&steps, editor_default_step(.Weld, test_parts))
	append(&steps, editor_default_step(.Assign, test_parts))
	editor_cycle_part(&steps[2], test_parts, 1)
	return
}

@(private = "file")
destroy_steps :: proc(steps: ^[dynamic]pipeline.Step) {
	for &step in steps do pipeline.step_destroy(&step)
	delete(steps^)
}

@(test)
test_editor_insert_step :: proc(t: ^testing.T) {
	steps := test_steps()
	defer destroy_steps(&steps)
	testing.expect_value(t, editor_insert_step(&steps, 0, .Import, test_parts), -1)
	index := editor_insert_step(&steps, 1, .Close, test_parts)
	testing.expect_value(t, index, 2)
	testing.expect_value(t, len(steps), 4)
	testing.expect_value(t, steps[2].op, pipeline.Op.Close)
	testing.expect_value(t, steps[2].part, "skirt")
	testing.expect(t, steps[2].enabled)
	testing.expect_value(t, steps[3].op, pipeline.Op.Assign)
	assign := editor_default_step(.Assign, nil)
	defer pipeline.step_destroy(&assign)
	testing.expect_value(t, assign.part, "part")
	testing.expect_value(t, assign.select.kind, pipeline.Select_Kind.Strokes)
}

@(test)
test_editor_delete_and_move_step :: proc(t: ^testing.T) {
	steps := test_steps()
	defer destroy_steps(&steps)
	testing.expect(t, !editor_delete_step(&steps, 0))
	testing.expect_value(t, editor_move_step(&steps, 1, -1), 1)
	testing.expect_value(t, editor_move_step(&steps, 0, 1), 0)
	testing.expect_value(t, editor_move_step(&steps, 2, 1), 2)
	testing.expect_value(t, editor_move_step(&steps, 1, 1), 2)
	testing.expect_value(t, steps[1].op, pipeline.Op.Assign)
	testing.expect_value(t, steps[2].op, pipeline.Op.Weld)
	testing.expect(t, editor_delete_step(&steps, 1))
	testing.expect_value(t, len(steps), 2)
	testing.expect_value(t, steps[1].op, pipeline.Op.Weld)
	editor_toggle_step(&steps[1])
	testing.expect(t, !steps[1].enabled)
}

@(test)
test_editor_strokes :: proc(t: ^testing.T) {
	step := pipeline.Step{op = .Assign, select = {kind = .Pieces, pieces = make([]string, 0)}}
	defer pipeline.step_destroy(&step)
	testing.expect(t, editor_brushable(step))
	editor_add_stroke(&step, {position = {0, 0, 0}, radius = 0.01})
	editor_add_stroke(&step, {position = {1, 0, 0}, radius = 0.01})
	testing.expect_value(t, step.select.kind, pipeline.Select_Kind.Strokes)
	testing.expect_value(t, len(step.select.strokes), 2)
	testing.expect(t, !editor_erase_stroke_near(&step, {0.5, 0, 0}, 0.01))
	testing.expect(t, editor_erase_stroke_near(&step, {0.995, 0, 0}, 0.01))
	testing.expect_value(t, len(step.select.strokes), 1)
	testing.expect_value(t, step.select.strokes[0].position, [3]f32{0, 0, 0})
	pieces := []string{"a"}
	listed := pipeline.Step{op = .Assign, select = {kind = .Pieces, pieces = pieces}}
	testing.expect(t, !editor_brushable(listed))
	testing.expect(t, !editor_brushable(pipeline.Step{op = .Delete, select = {kind = .Strokes}}))
}

@(test)
test_editor_adjust_key :: proc(t: ^testing.T) {
	step := editor_default_step(.Transform, test_parts)
	defer pipeline.step_destroy(&step)
	editor_adjust_key(&step, .Height, 1, test_parts)
	testing.expect(t, math.abs(step.height - 1.05) < 1e-5)
	for _ in 0 ..< 400 do editor_adjust_key(&step, .Height, 1, test_parts)
	testing.expect_value(t, step.height, EDITOR_HEIGHT_RANGE.maximum)
	editor_reset_key(&step, .Height, test_parts)
	testing.expect_value(t, step.height, f32(1))
	editor_adjust_key(&step, .Front, -1, test_parts)
	testing.expect_value(t, step.front, pipeline.Front.Minus_Z)
	weld := editor_default_step(.Weld, test_parts)
	defer pipeline.step_destroy(&weld)
	editor_adjust_key(&weld, .Metres, 1, test_parts)
	testing.expect(t, math.abs(weld.metres - 0.0001) < 1e-9)
	copy_step := editor_default_step(.Copy, test_parts)
	defer pipeline.step_destroy(&copy_step)
	editor_adjust_key(&copy_step, .Turn, -1, test_parts)
	testing.expect_value(t, copy_step.turn, 3)
	editor_adjust_key(&copy_step, .To_Y, 1, test_parts)
	testing.expect(t, math.abs(copy_step.to.y - 0.01) < 1e-6)
	close := editor_default_step(.Close, test_parts)
	defer pipeline.step_destroy(&close)
	editor_adjust_key(&close, .Part, -1, test_parts)
	testing.expect_value(t, close.part, "lid")
	editor_adjust_key(&close, .Part, 1, test_parts)
	testing.expect_value(t, close.part, "skirt")
	editor_adjust_key(&close, .Technique, 1, test_parts)
	testing.expect_value(t, close.technique, pipeline.Close_Technique.Fill)
	editor_adjust_key(&close, .Trim, -1, test_parts)
	testing.expect(t, math.abs(close.trim - 0.002) < 1e-6)
}

@(test)
test_editor_index_after :: proc(t: ^testing.T) {
	insert := Editor_Change{kind = .Insert, index = 2}
	testing.expect_value(t, editor_index_after(insert, 1), 1)
	testing.expect_value(t, editor_index_after(insert, 2), 3)
	removal := Editor_Change{kind = .Delete, index = 2}
	testing.expect_value(t, editor_index_after(removal, 2), -1)
	testing.expect_value(t, editor_index_after(removal, 3), 2)
	testing.expect_value(t, editor_index_after(removal, 1), 1)
	swap := Editor_Change{kind = .Swap, index = 2, other = 3}
	testing.expect_value(t, editor_index_after(swap, 2), 3)
	testing.expect_value(t, editor_index_after(swap, 3), 2)
	testing.expect_value(t, editor_index_after(swap, 4), 4)
}

@(test)
test_editor_stroke_lines :: proc(t: ^testing.T) {
	lines := editor_stroke_lines({120, 4, 0, 9})
	testing.expect_value(t, len(lines), 2)
	testing.expect_value(t, lines[0], "#0 120  #1 4  #2 0")
	testing.expect_value(t, lines[1], "#3 9")
}

// Every inserted step saves to a file that parses back, a select of no
// strokes included.
@(test)
test_editor_inserted_steps_round_trip :: proc(t: ^testing.T) {
	steps := test_steps()
	for op in EDITOR_INSERTABLE_OPS do editor_insert_step(&steps, len(steps) - 1, op, test_parts)
	editor_add_stroke(&steps[2], {position = {0.1, 0.2, 0.3}, radius = 0.01})
	saved := pipeline.Pipeline{source = "model.glb", steps = steps}
	text := pipeline.pipeline_save(saved)
	defer delete(text)
	destroy_steps(&steps)
	parsed, problem := pipeline.pipeline_parse(transmute([]byte)text)
	defer pipeline.pipeline_destroy(&parsed)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(parsed.steps), 3 + len(EDITOR_INSERTABLE_OPS))
	testing.expect_value(t, len(parsed.steps[2].select.strokes), 1)
}
