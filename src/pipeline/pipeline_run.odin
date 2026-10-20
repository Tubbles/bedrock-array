#+build !js
package pipeline

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sync"
import "core:thread"

// The floor of a part's share of a decimate budget, as
// tools/models/finish_parts.sh's MINIMUM_TRIANGLES.
MINIMUM_TRIANGLES :: 24
// The Poisson cell of the close step, as finish_parts.sh's CELL.
POISSON_CELL :: "0.0025"

Step_State :: enum {
	Stale,
	Running,
	Done,
	Failed,
}

// message is the failure's text, owned by the status.
Step_Status :: struct {
	state:   Step_State,
	message: string,
}

// One external tool run on one part: the part's triangles are written to
// input_path, the command makes output_path, and its triangles replace
// the part's in a new piece named piece_name. The task owns its strings.
Heavy_Task :: struct {
	part:        u16,
	input_path:  string,
	output_path: string,
	piece_name:  string,
	command:     []string,
}

// A heavy step on the worker thread. The worker writes only result,
// problem and then done. The main thread reads them once done is set and
// alone touches discard.
Heavy_Job :: struct {
	step_index: int,
	root:       string,
	input:      Pipeline_Mesh,
	tasks:      [dynamic]Heavy_Task,
	result:     Pipeline_Mesh,
	problem:    string,
	done:       bool,
	discard:    bool,
	worker:     ^thread.Thread,
}

// A pipeline being run: outputs[n] is step n's output, every step before
// it done. root is the project's absolute path and machine the machine's
// id. The run owns the pipeline and its strings.
Run :: struct {
	pipeline: Pipeline,
	root:     string,
	machine:  string,
	outputs:  [dynamic]Pipeline_Mesh,
	status:   [dynamic]Step_Status,
	job:      ^Heavy_Job,
}

run_make :: proc(pipeline: Pipeline, root, machine: string) -> Run {
	run := Run {
		pipeline = pipeline,
		root     = strings.clone(root),
		machine  = strings.clone(machine),
	}
	resize(&run.status, len(pipeline.steps))
	return run
}

// Waits for a running tool to finish, then frees everything.
run_destroy :: proc(run: ^Run) {
	if run.job != nil {
		thread.destroy(run.job.worker)
		heavy_job_destroy(run.job)
	}
	for &output in run.outputs {
		pipeline_mesh_destroy(&output)
	}
	delete(run.outputs)
	for status in run.status {
		delete(status.message)
	}
	delete(run.status)
	pipeline_destroy(&run.pipeline)
	delete(run.root)
	delete(run.machine)
	run^ = {}
}

is_heavy :: proc(step: Step) -> bool {
	return step.enabled && (step.op == .Decimate || step.op == .Close)
}

// Marks the steps from index on stale, drops their outputs and runs the
// native steps that follow at once. A tool still running for a step from
// index on finishes, and its result is dropped. Call it after any edit
// of the steps.
run_from :: proc(run: ^Run, index: int) {
	first := clamp(index, 0, len(run.pipeline.steps))
	for &status in run.status[min(first, len(run.status)):] {
		delete(status.message)
		status = {}
	}
	resize(&run.status, len(run.pipeline.steps))
	for &output in run.outputs[min(first, len(run.outputs)):] {
		pipeline_mesh_destroy(&output)
	}
	resize(&run.outputs, min(first, len(run.outputs)))
	if run.job != nil && run.job.step_index >= first {
		run.job.discard = true
	}
	run_advance(run)
}

// Called each frame: collects a finished tool run, runs the native steps
// after it and starts the next heavy step on the worker.
run_poll :: proc(run: ^Run) {
	if run.job != nil && sync.atomic_load(&run.job.done) {
		run_collect(run)
		run_advance(run)
	}
	next := len(run.outputs)
	if run.job != nil || next >= len(run.pipeline.steps) || run.status[next].state != .Stale {
		return
	}
	run_start(run, next)
}

set_status :: proc(run: ^Run, index: int, state: Step_State, message := "") {
	delete(run.status[index].message)
	run.status[index] = {state, strings.clone(message)}
}

// Runs native steps in order until a heavy one, a failure or the end.
run_advance :: proc(run: ^Run) {
	for len(run.outputs) < len(run.pipeline.steps) {
		index := len(run.outputs)
		if run.status[index].state == .Failed || is_heavy(run.pipeline.steps[index]) {
			return
		}
		output, problem := run_native_step(run^, index)
		if problem != "" {
			set_status(run, index, .Failed, problem)
			return
		}
		append(&run.outputs, output)
		set_status(run, index, .Done)
	}
}

read_source :: proc(root, source: string) -> (mesh: Pipeline_Mesh, problem: string) {
	path := fmt.tprintf("%s/%s", root, source)
	data, error := os.read_entire_file_from_path(path, context.allocator)
	defer delete(data)
	if error != nil {
		return {}, fmt.tprintf("import: reading %s: %v", path, error)
	}
	return read_glb(data)
}

apply_select_step :: proc(mesh: ^Pipeline_Mesh, step: Step) {
	selected := select_triangles(mesh^, step.select)
	defer delete(selected)
	#partial switch step.op {
	case .Assign:
		step_assign(mesh, step.part, selected)
	case .Delete:
		step_delete(mesh, selected)
	case .Copy:
		step_copy(mesh, selected, step.from, step.to, step.turn)
	}
}

// The output of a native step, or of a disabled step, which passes its
// input on. The import step always reads the source.
run_native_step :: proc(run: Run, index: int) -> (mesh: Pipeline_Mesh, problem: string) {
	step := run.pipeline.steps[index]
	if step.op == .Import {
		return read_source(run.root, run.pipeline.source)
	}
	if index == 0 {
		return {}, "step 0: must be import"
	}
	mesh = pipeline_mesh_clone(run.outputs[index - 1])
	if !step.enabled {
		return mesh, ""
	}
	#partial switch step.op {
	case .Transform:
		step_transform(&mesh, step.front, step.height)
	case .Weld:
		step_weld(&mesh, step.metres)
	case .Assign, .Delete, .Copy:
		apply_select_step(&mesh, step)
	}
	return mesh, ""
}

// Each part's share of total, by its triangle count, at least
// MINIMUM_TRIANGLES: max(minimum, round(total * count / sum)) in integer
// arithmetic, as finish_parts.sh's budget.
decimate_budgets :: proc(counts: []int, total: int, allocator := context.allocator) -> []int {
	sum := 0
	for count in counts {
		sum += count
	}
	budgets := make([]int, len(counts), allocator)
	for count, index in counts {
		share := sum > 0 ? (2 * total * count + sum) / (2 * sum) : 0
		budgets[index] = max(share, MINIMUM_TRIANGLES)
	}
	return budgets
}

part_triangle_counts :: proc(mesh: Pipeline_Mesh, allocator := context.allocator) -> []int {
	counts := make([]int, len(mesh.part_names), allocator)
	for part in mesh.parts {
		if part != PART_NONE {
			counts[part] += 1
		}
	}
	return counts
}

clone_command :: proc(words: []string) -> []string {
	command := make([]string, len(words))
	for word, index in words {
		command[index] = strings.clone(word)
	}
	return command
}

decimate_task :: proc(root, directory, part_name: string, part: u16, triangles: int) -> Heavy_Task {
	input := fmt.tprintf("%s/%s.ply", directory, part_name)
	output := fmt.tprintf("%s/%s_decimated.glb", directory, part_name)
	script := fmt.tprintf("%s/tools/models/decimate.py", root)
	words := []string{"flatpak", "run", "org.blender.Blender", "-b", "--python", script, "--", input, output, "--triangles", fmt.tprintf("%d", triangles)}
	return {part, strings.clone(input), strings.clone(output), fmt.aprintf("%s_decimated", part_name), clone_command(words)}
}

close_task :: proc(root, directory, part_name: string, part: u16, technique: Close_Technique, trim: f32) -> Heavy_Task {
	if technique == .Fill {
		input := fmt.tprintf("%s/%s.glb", directory, part_name)
		output := fmt.tprintf("%s/%s_closed.glb", directory, part_name)
		script := fmt.tprintf("%s/tools/models/close.py", root)
		words := []string{"flatpak", "run", "org.blender.Blender", "-b", "--python", script, "--", input, output, "--technique", "fill"}
		return {part, strings.clone(input), strings.clone(output), fmt.aprintf("%s_closed", part_name), clone_command(words)}
	}
	input := fmt.tprintf("%s/%s.ply", directory, part_name)
	output := fmt.tprintf("%s/%s_closed.ply", directory, part_name)
	script := fmt.tprintf("%s/tools/models/reconstruct.py", root)
	words := []string{script, input, output, "--technique", "poisson", "--cell", POISSON_CELL, "--trim", fmt.tprintf("%v", trim)}
	return {part, strings.clone(input), strings.clone(output), fmt.aprintf("%s_closed", part_name), clone_command(words)}
}

heavy_task_destroy :: proc(task: ^Heavy_Task) {
	delete(task.input_path)
	delete(task.output_path)
	delete(task.piece_name)
	for word in task.command {
		delete(word)
	}
	delete(task.command)
}

// The tool runs of a heavy step on its input, under
// <root>/work/models/<machine>/pipeline/step<n>/: decimate one per part
// with triangles, close one for its part.
plan_heavy_tasks :: proc(root, machine: string, step_index: int, step: Step, input: Pipeline_Mesh) -> (tasks: [dynamic]Heavy_Task, problem: string) {
	directory := fmt.tprintf("%s/work/models/%s/pipeline/step%d", root, machine, step_index)
	counts := part_triangle_counts(input)
	defer delete(counts)
	if step.op == .Close {
		part, found := find_part(input, step.part)
		if !found || counts[part] == 0 {
			return nil, fmt.tprintf("step %d: part %s has no triangles", step_index, step.part)
		}
		append(&tasks, close_task(root, directory, step.part, part, step.technique, step.trim))
		return tasks, ""
	}
	present := make([dynamic]int, context.temp_allocator)
	for count, part in counts {
		if count > 0 {
			append(&present, part)
		}
	}
	if len(present) == 0 {
		return nil, fmt.tprintf("step %d: no triangle has a part to decimate", step_index)
	}
	present_counts := make([]int, len(present), context.temp_allocator)
	for part, index in present {
		present_counts[index] = counts[part]
	}
	budgets := decimate_budgets(present_counts, step.triangles, context.temp_allocator)
	for part, index in present {
		append(&tasks, decimate_task(root, directory, input.part_names[part], u16(part), budgets[index]))
	}
	return tasks, ""
}

// Replaces the part's triangles with the addition's, as a new piece of
// that part.
merge_part_result :: proc(mesh: ^Pipeline_Mesh, part: u16, addition: Pipeline_Mesh, piece_name: string) {
	drop := make([]bool, len(mesh.triangles))
	defer delete(drop)
	for triangle_part, index in mesh.parts {
		drop[index] = triangle_part == part
	}
	keep_triangles(mesh, drop)
	compact_vertices(mesh)
	append(&mesh.piece_names, strings.clone(piece_name))
	piece := u32(len(mesh.piece_names) - 1)
	base := u32(len(mesh.positions))
	append(&mesh.positions, ..addition.positions[:])
	append(&mesh.normals, ..addition.normals[:])
	for triangle in addition.triangles {
		append(&mesh.triangles, triangle + base)
		append(&mesh.pieces, piece)
		append(&mesh.parts, part)
	}
}

// The last line of a tool's error output.
last_line :: proc(text: string) -> string {
	trimmed := strings.trim_right_space(text)
	return trimmed[strings.last_index_byte(trimmed, '\n') + 1:]
}

write_task_input :: proc(input: Pipeline_Mesh, task: Heavy_Task) -> (problem: string) {
	selected := make([]bool, len(input.triangles))
	defer delete(selected)
	for part, index in input.parts {
		selected[index] = part == task.part
	}
	if strings.has_suffix(task.input_path, ".glb") {
		data := glb_bytes(input, selected, task.piece_name)
		defer delete(data)
		if error := os.write_entire_file(task.input_path, data); error != nil {
			return fmt.tprintf("writing %s: %v", task.input_path, error)
		}
		return ""
	}
	return write_ply(task.input_path, input, selected)
}

read_task_output :: proc(path: string) -> (mesh: Pipeline_Mesh, problem: string) {
	data, error := os.read_entire_file_from_path(path, context.allocator)
	defer delete(data)
	if error != nil {
		return {}, fmt.tprintf("reading %s: %v", path, error)
	}
	if strings.has_suffix(path, ".glb") {
		return read_glb(data)
	}
	return read_ply(data)
}

execute_task :: proc(root: string, task: Heavy_Task) -> (problem: string) {
	state, stdout, stderr, error := os.process_exec({working_dir = root, command = task.command}, context.allocator)
	defer delete(stdout)
	defer delete(stderr)
	if error != nil {
		return fmt.tprintf("could not run %s: %v", task.command[0], error)
	}
	if !state.success || state.exit_code != 0 {
		line := last_line(string(stderr))
		return line != "" ? fmt.tprintf("%s", line) : fmt.tprintf("%s exited with %d", task.command[0], state.exit_code)
	}
	return ""
}

run_task :: proc(root: string, input: Pipeline_Mesh, result: ^Pipeline_Mesh, task: Heavy_Task) -> (problem: string) {
	directory := task.input_path[:strings.last_index_byte(task.input_path, '/')]
	if error := os.make_directory_all(directory); error != nil && error != .Exist {
		return fmt.tprintf("making %s: %v", directory, error)
	}
	if problem = write_task_input(input, task); problem != "" {
		return
	}
	if problem = execute_task(root, task); problem != "" {
		return
	}
	output, output_problem := read_task_output(task.output_path)
	defer pipeline_mesh_destroy(&output)
	if output_problem != "" {
		return output_problem
	}
	merge_part_result(result, task.part, output, task.piece_name)
	return ""
}

// The worker thread: one tool at a time, the result merged part by part.
heavy_job_work :: proc(job: ^Heavy_Job) {
	result := pipeline_mesh_clone(job.input)
	for task in job.tasks {
		if problem := run_task(job.root, job.input, &result, task); problem != "" {
			job.problem = strings.clone(problem)
			break
		}
	}
	job.result = result
	sync.atomic_store(&job.done, true)
}

heavy_job_destroy :: proc(job: ^Heavy_Job) {
	pipeline_mesh_destroy(&job.input)
	pipeline_mesh_destroy(&job.result)
	for &task in job.tasks {
		heavy_task_destroy(&task)
	}
	delete(job.tasks)
	delete(job.problem)
	delete(job.root)
	free(job)
}

run_start :: proc(run: ^Run, index: int) {
	input := run.outputs[index - 1]
	tasks, problem := plan_heavy_tasks(run.root, run.machine, index, run.pipeline.steps[index], input)
	if problem != "" {
		set_status(run, index, .Failed, problem)
		return
	}
	job := new(Heavy_Job)
	job^ = {step_index = index, root = strings.clone(run.root), input = pipeline_mesh_clone(input), tasks = tasks}
	run.job = job
	set_status(run, index, .Running)
	job.worker = thread.create_and_start_with_poly_data(job, heavy_job_work)
}

run_collect :: proc(run: ^Run) {
	job := run.job
	run.job = nil
	thread.destroy(job.worker)
	defer heavy_job_destroy(job)
	if job.discard || job.step_index != len(run.outputs) {
		return
	}
	if job.problem != "" {
		set_status(run, job.step_index, .Failed, job.problem)
		return
	}
	append(&run.outputs, job.result)
	job.result = {}
	set_status(run, job.step_index, .Done)
}

// The blob suffix: empty, or _<triangles> of the last enabled decimate
// among the done steps.
export_suffix :: proc(run: Run) -> string {
	suffix := ""
	for step in run.pipeline.steps[:len(run.outputs)] {
		if step.op == .Decimate && step.enabled {
			suffix = fmt.tprintf("_%d", step.triangles)
		}
	}
	return suffix
}

// Writes the last done step's mesh as one blob per part to
// data/demos/parts/meshes/. The problem text lives in
// context.temp_allocator.
run_export :: proc(run: Run) -> (problem: string) {
	if len(run.outputs) == 0 {
		return "export: no step is done"
	}
	directory := fmt.tprintf("%s/data/demos/parts/meshes", run.root)
	return write_part_blobs(run.outputs[len(run.outputs) - 1], directory, export_suffix(run))
}
