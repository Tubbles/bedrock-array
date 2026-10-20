#+build !js
package pipeline

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

EVERY_OP_FILE :: `// Every op once.
source = "work/models/test/model.glb"
steps = [
	{ op = "transform", front = "+x", height = 1.5, note = "turn it" }
	{ op = "weld", metres = 0.001 }
	{ op = "assign", part = "body", select = { pieces = ["first", "second"], within_part = "lid" } }
	{ op = "assign", part = "lid", select = { strokes = [
		{ position = [0, 1, 0], radius = 0.25 }
		{ position = [1, 2, 3], radius = 0.5 }
	] } }
	{ op = "delete", select = { box = { min = [-1, -2, -3], max = [1, 2, 3] } } }
	{ op = "copy", select = { sphere = { centre = [0, 1, 0], radius = 2 } }, from = [0, 0, 0], to = [1, 0, 0], turn = 2 }
	{ op = "decimate", triangles = 4000, enabled = false }
	{ op = "close", part = "body", technique = "poisson", trim = 0.003 }
	{ op = "close", part = "lid", technique = "fill", trim = 0 }
	{ op = "delete", select = { part = "lid" } }
]
`

parse_text :: proc(t: ^testing.T, text: string, loc := #caller_location) -> Pipeline {
	pipeline, problem := pipeline_parse(transmute([]byte)text)
	testing.expect_value(t, problem, "", loc = loc)
	return pipeline
}

parse_problem :: proc(text: string) -> string {
	pipeline, problem := pipeline_parse(transmute([]byte)text)
	pipeline_destroy(&pipeline)
	return problem
}

@(test)
test_parse_every_op :: proc(t: ^testing.T) {
	pipeline := parse_text(t, EVERY_OP_FILE)
	defer pipeline_destroy(&pipeline)
	testing.expect_value(t, pipeline.source, "work/models/test/model.glb")
	testing.expect_value(t, len(pipeline.steps), 11)
	steps := pipeline.steps[:]
	testing.expect_value(t, steps[0].op, Op.Import)
	testing.expect_value(t, steps[1].front, Front.Plus_X)
	testing.expect_value(t, steps[1].height, 1.5)
	testing.expect_value(t, steps[1].note, "turn it")
	testing.expect_value(t, steps[2].metres, 0.001)
	testing.expect_value(t, steps[3].select.kind, Select_Kind.Pieces)
	testing.expect_value(t, steps[3].select.pieces[1], "second")
	testing.expect_value(t, steps[3].select.within_part, "lid")
	testing.expect_value(t, steps[4].part, "lid")
	testing.expect_value(t, len(steps[4].select.strokes), 2)
	testing.expect_value(t, steps[4].select.strokes[1], Stroke{{1, 2, 3}, 0.5})
	testing.expect_value(t, steps[5].select.minimum, [3]f32{-1, -2, -3})
	testing.expect_value(t, steps[5].select.maximum, [3]f32{1, 2, 3})
	testing.expect_value(t, steps[6].select.centre, [3]f32{0, 1, 0})
	testing.expect_value(t, steps[6].select.radius, 2)
	testing.expect_value(t, steps[6].to, [3]f32{1, 0, 0})
	testing.expect_value(t, steps[6].turn, 2)
	testing.expect_value(t, steps[7].triangles, 4000)
	testing.expect(t, !steps[7].enabled)
	testing.expect(t, steps[8].enabled)
	testing.expect_value(t, steps[8].technique, Close_Technique.Poisson)
	testing.expect_value(t, steps[8].trim, 0.003)
	testing.expect_value(t, steps[9].technique, Close_Technique.Fill)
	testing.expect_value(t, steps[10].select.part, "lid")
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "weld", metres = 1 }, { op = "import" } ]`), "step 1: import only as the first step")
}

@(test)
test_parse_rejects_an_unknown_key :: proc(t: ^testing.T) {
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "import" }, { op = "weld", metres = 1, height = 2 } ]`), "step 1: unknown key height")
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "delete", select = { part = "a", colour = 1 } } ]`), "step 0 select: unknown key colour")
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "delete", select = { part = "a", box = { min = [0, 0, 0], max = [1, 1, 1] } } } ]`), "step 0 select: needs exactly one of pieces, part, box, sphere and strokes")
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "weld" } ]`), "step 0: metres missing")
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [ { op = "melt" } ]`), `step 0: op "melt" is unknown`)
	testing.expect_value(t, parse_problem(`source = "a.glb", steps = [], extra = 1`), "pipeline: unknown key extra")
}

steps_equal :: proc(a, b: Step) -> bool {
	if a.op != b.op || a.enabled != b.enabled || a.note != b.note || a.front != b.front || a.height != b.height || a.metres != b.metres || a.part != b.part {
		return false
	}
	if a.technique != b.technique || a.trim != b.trim || a.triangles != b.triangles || a.from != b.from || a.to != b.to || a.turn != b.turn {
		return false
	}
	x, y := a.select, b.select
	if x.kind != y.kind || x.part != y.part || x.minimum != y.minimum || x.maximum != y.maximum || x.centre != y.centre || x.radius != y.radius || x.within_part != y.within_part {
		return false
	}
	if len(x.pieces) != len(y.pieces) || len(x.strokes) != len(y.strokes) {
		return false
	}
	for piece, index in x.pieces {
		if piece != y.pieces[index] {
			return false
		}
	}
	for stroke, index in x.strokes {
		if stroke != y.strokes[index] {
			return false
		}
	}
	return true
}

@(test)
test_save_round_trips :: proc(t: ^testing.T) {
	pipeline := parse_text(t, EVERY_OP_FILE)
	defer pipeline_destroy(&pipeline)
	saved := pipeline_save(pipeline)
	defer delete(saved)
	testing.expect(t, strings.has_prefix(saved, "source = \"work/models/test/model.glb\"\nsteps = [\n\t{ op = \"import\" }\n"))
	again := parse_text(t, saved)
	defer pipeline_destroy(&again)
	testing.expect_value(t, again.source, pipeline.source)
	testing.expect_value(t, len(again.steps), len(pipeline.steps))
	for step, index in pipeline.steps {
		testing.expectf(t, steps_equal(step, again.steps[index]), "step %d differs after the round trip", index)
	}
	saved_again := pipeline_save(again)
	defer delete(saved_again)
	testing.expect_value(t, saved_again, saved)
}

NATIVE_FILE :: `source = "model.glb"
steps = [
	{ op = "import" }
	{ op = "transform", front = "+z", height = 2 }
	{ op = "weld", metres = 0.0001 }
	{ op = "assign", part = "body", select = { pieces = ["first"] } }
	{ op = "copy", select = { part = "body" }, from = [0, 0, 0], to = [5, 0, 0], turn = 1 }
	{ op = "delete", select = { pieces = ["second"] } }
	{ op = "weld", metres = 9, enabled = false }
]
`

// A run of NATIVE_FILE over the hand built GLB in a fresh directory.
// The caller removes the directory and destroys the run.
make_native_run :: proc(t: ^testing.T) -> (run: Run, directory: string) {
	error: os.Error
	directory, error = os.make_directory_temp("", "pipeline_run_test_*", context.allocator)
	testing.expect_value(t, error, nil)
	glb := hand_built_glb()
	defer delete(glb)
	testing.expect_value(t, os.write_entire_file(fmt.tprintf("%s/model.glb", directory), glb), nil)
	run = run_make(parse_text(t, NATIVE_FILE), directory, "test")
	return run, directory
}

@(test)
test_run_native_steps_in_order :: proc(t: ^testing.T) {
	run, directory := make_native_run(t)
	defer delete(directory)
	defer os.remove_all(directory)
	defer run_destroy(&run)
	run_from(&run, 0)
	testing.expect_value(t, len(run.outputs), 7)
	for status, index in run.status {
		testing.expectf(t, status.state == .Done, "step %d is %v: %s", index, status.state, status.message)
	}
	glb := hand_built_glb()
	defer delete(glb)
	expected, _ := read_glb(glb)
	defer pipeline_mesh_destroy(&expected)
	step_transform(&expected, .Plus_Z, 2)
	step_weld(&expected, 0.0001)
	step_assign(&expected, "body", []bool{true, false})
	step_copy(&expected, []bool{true, false}, {0, 0, 0}, {5, 0, 0}, 1)
	step_delete(&expected, []bool{false, true, false})
	last := run.outputs[6]
	testing.expect_value(t, len(last.triangles), len(expected.triangles))
	testing.expect_value(t, len(last.positions), len(expected.positions))
	for position, index in expected.positions {
		expect_near(t, last.positions[index], position)
	}
	testing.expect_value(t, last.piece_names[2], "copy_1")
	testing.expect_value(t, last.parts[1], 0)
	testing.expect_value(t, len(run.outputs[0].triangles), 2)
	testing.expect_value(t, len(run.outputs[4].triangles), 3)
}

@(test)
test_rerun_from_keeps_earlier_outputs :: proc(t: ^testing.T) {
	run, directory := make_native_run(t)
	defer delete(directory)
	defer os.remove_all(directory)
	defer run_destroy(&run)
	run_from(&run, 0)
	kept := raw_data(run.outputs[2].positions)
	run.pipeline.steps[4].to = {7, 0, 0}
	run_from(&run, 4)
	testing.expect_value(t, len(run.outputs), 7)
	testing.expect(t, raw_data(run.outputs[2].positions) == kept)
	copied := run.outputs[4].triangles[2]
	testing.expect(t, run.outputs[4].positions[copied[0]].x > 6.5)
	// A heavy step waits for run_poll, and the steps after it stay stale.
	inject_at(&run.pipeline.steps, 6, Step{op = .Decimate, enabled = true, triangles = 100})
	run_from(&run, 6)
	testing.expect_value(t, len(run.outputs), 6)
	testing.expect_value(t, run.status[6].state, Step_State.Stale)
	testing.expect_value(t, run.status[7].state, Step_State.Stale)
	testing.expect(t, run.job == nil)
}

@(test)
test_decimate_budgets_share_with_a_floor :: proc(t: ^testing.T) {
	budgets := decimate_budgets([]int{9000, 1000, 10}, 1000)
	defer delete(budgets)
	// round(1000 * 9000 / 10010), round(1000 * 1000 / 10010), then the floor.
	testing.expect_value(t, budgets[0], 899)
	testing.expect_value(t, budgets[1], 100)
	testing.expect_value(t, budgets[2], MINIMUM_TRIANGLES)
}

@(test)
test_heavy_tasks_build_the_commands :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	step_assign(&mesh, "body", []bool{true, true, true, false})
	step_assign(&mesh, "lid", []bool{false, false, false, true})
	tasks, problem := plan_heavy_tasks("/project", "smelter", 3, {op = .Decimate, enabled = true, triangles = 400}, mesh)
	defer delete(tasks)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(tasks), 2)
	directory :: "/project/work/models/smelter/pipeline/step3"
	expected := []string{"flatpak", "run", "org.blender.Blender", "-b", "--python", "/project/tools/models/decimate.py", "--", directory + "/body.ply", directory + "/body_decimated.glb", "--triangles", "300"}
	testing.expect_value(t, len(tasks[0].command), len(expected))
	for word, index in expected {
		testing.expect_value(t, tasks[0].command[index], word)
	}
	testing.expect_value(t, tasks[1].command[10], "100")
	testing.expect_value(t, tasks[1].piece_name, "lid_decimated")
	for &task in tasks {
		heavy_task_destroy(&task)
	}
	close_tasks, close_problem := plan_heavy_tasks("/project", "smelter", 4, {op = .Close, enabled = true, part = "lid", technique = .Poisson, trim = 0.003}, mesh)
	defer delete(close_tasks)
	testing.expect_value(t, close_problem, "")
	testing.expect_value(t, len(close_tasks), 1)
	close_expected := []string{"/project/tools/models/reconstruct.py", "/project/work/models/smelter/pipeline/step4/lid.ply", "/project/work/models/smelter/pipeline/step4/lid_closed.ply", "--technique", "poisson", "--cell", "0.0025", "--trim", "0.003"}
	for word, index in close_expected {
		testing.expect_value(t, close_tasks[0].command[index], word)
	}
	testing.expect_value(t, close_tasks[0].part, 1)
	heavy_task_destroy(&close_tasks[0])
	fill_tasks, _ := plan_heavy_tasks("/project", "smelter", 4, {op = .Close, enabled = true, part = "body", technique = .Fill}, mesh)
	defer delete(fill_tasks)
	testing.expect_value(t, fill_tasks[0].input_path, "/project/work/models/smelter/pipeline/step4/body.glb")
	testing.expect_value(t, fill_tasks[0].command[len(fill_tasks[0].command) - 1], "fill")
	heavy_task_destroy(&fill_tasks[0])
	_, missing_problem := plan_heavy_tasks("/project", "smelter", 4, {op = .Close, enabled = true, part = "base"}, mesh)
	testing.expect_value(t, missing_problem, "step 4: part base has no triangles")
}

@(test)
test_merge_part_result_replaces_the_part :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	step_assign(&mesh, "body", []bool{true, true, false, false})
	glb := glb_bytes(mesh, []bool{false, false, true, false}, "anything")
	defer delete(glb)
	addition, problem := read_glb(glb)
	defer pipeline_mesh_destroy(&addition)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(addition.triangles), 1)
	expect_near(t, addition.positions[addition.triangles[0][1]], {3, 0, 0})
	merge_part_result(&mesh, 0, addition, "body_decimated")
	testing.expect_value(t, len(mesh.triangles), 3)
	testing.expect_value(t, len(mesh.positions), 7)
	testing.expect_value(t, mesh.piece_names[2], "body_decimated")
	testing.expect_value(t, mesh.pieces[2], 2)
	testing.expect_value(t, mesh.parts[2], 0)
	testing.expect_value(t, mesh.parts[0], PART_NONE)
	expect_near(t, mesh.positions[mesh.triangles[2][1]], {3, 0, 0})
	testing.expect_value(t, last_line("first\nsecond line\n\n"), "second line")
	testing.expect_value(t, last_line("only"), "only")
}
