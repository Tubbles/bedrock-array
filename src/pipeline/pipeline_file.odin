#+build !js
package pipeline

import "core:encoding/json"
import "core:fmt"
import "core:strings"

// A problem text in context.temp_allocator, nil when all is well, so
// the parse helpers chain with or_return.
Problem :: Maybe(string)

// The ops of doc/workflows/pipeline_editor.md, The pipeline file.
Op :: enum {
	Import,
	Transform,
	Weld,
	Assign,
	Delete,
	Copy,
	Decimate,
	Close,
}

OP_NAMES := [Op]string {
	.Import    = "import",
	.Transform = "transform",
	.Weld      = "weld",
	.Assign    = "assign",
	.Delete    = "delete",
	.Copy      = "copy",
	.Decimate  = "decimate",
	.Close     = "close",
}

// The keys each op takes besides op, note and enabled, all required.
OP_KEYS := [Op][]string {
	.Import    = {},
	.Transform = {"front", "height"},
	.Weld      = {"metres"},
	.Assign    = {"part", "select"},
	.Delete    = {"select"},
	.Copy      = {"select", "from", "to", "turn"},
	.Decimate  = {"triangles"},
	.Close     = {"part", "technique", "trim"},
}

FRONT_NAMES := [Front]string {
	.Plus_X  = "+x",
	.Minus_X = "-x",
	.Plus_Z  = "+z",
	.Minus_Z = "-z",
}

Close_Technique :: enum {
	Poisson,
	Fill,
}

TECHNIQUE_NAMES := [Close_Technique]string {
	.Poisson = "poisson",
	.Fill    = "fill",
}

// One step; only the keys of its op are meaningful.
Step :: struct {
	op:        Op,
	enabled:   bool,
	note:      string,
	front:     Front,
	height:    f32,
	metres:    f32,
	part:      string,
	technique: Close_Technique,
	trim:      f32,
	triangles: int,
	from:      [3]f32,
	to:        [3]f32,
	turn:      int,
	select:    Select,
}

// The pipeline owns every string and slice of its steps.
Pipeline :: struct {
	source: string,
	steps:  [dynamic]Step,
}

step_destroy :: proc(step: ^Step) {
	delete(step.note)
	delete(step.part)
	for piece in step.select.pieces {
		delete(piece)
	}
	delete(step.select.pieces)
	delete(step.select.part)
	delete(step.select.strokes)
	delete(step.select.within_part)
	step^ = {}
}

pipeline_destroy :: proc(pipeline: ^Pipeline) {
	for &step in pipeline.steps {
		step_destroy(&step)
	}
	delete(pipeline.steps)
	delete(pipeline.source)
	pipeline^ = {}
}

check_keys :: proc(owner: string, fields: json.Object, allowed: []string) -> (problem: Problem) {
	key_loop: for key in fields {
		for allowed_key in allowed {
			if key == allowed_key {
				continue key_loop
			}
		}
		return fmt.tprintf("%s: unknown key %s", owner, key)
	}
	return nil
}

json_number :: proc(value: json.Value) -> (number: f64, ok: bool) {
	#partial switch typed in value {
	case json.Integer:
		return f64(typed), true
	case json.Float:
		return typed, true
	}
	return 0, false
}

number_field :: proc(owner, key: string, fields: json.Object) -> (number: f32, problem: Problem) {
	value, present := fields[key]
	if !present {
		return 0, fmt.tprintf("%s: %s missing", owner, key)
	}
	wide, is_number := json_number(value)
	if !is_number {
		return 0, fmt.tprintf("%s: %s must be a number", owner, key)
	}
	return f32(wide), nil
}

integer_field :: proc(owner, key: string, fields: json.Object) -> (integer: int, problem: Problem) {
	value, present := fields[key]
	if !present {
		return 0, fmt.tprintf("%s: %s missing", owner, key)
	}
	typed, is_integer := value.(json.Integer)
	if !is_integer {
		return 0, fmt.tprintf("%s: %s must be a whole number", owner, key)
	}
	return int(typed), nil
}

string_field :: proc(owner, key: string, fields: json.Object) -> (text: string, problem: Problem) {
	value, present := fields[key]
	if !present {
		return "", fmt.tprintf("%s: %s missing", owner, key)
	}
	typed, is_string := value.(json.String)
	if !is_string {
		return "", fmt.tprintf("%s: %s must be a string", owner, key)
	}
	return typed, nil
}

json_vector :: proc(value: json.Value) -> (vector: [3]f32, ok: bool) {
	array, is_array := value.(json.Array)
	if !is_array || len(array) != 3 {
		return {}, false
	}
	for element, axis in array {
		number := json_number(element) or_return
		vector[axis] = f32(number)
	}
	return vector, true
}

vector_field :: proc(owner, key: string, fields: json.Object) -> (vector: [3]f32, problem: Problem) {
	value, present := fields[key]
	if !present {
		return {}, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_vector: bool
	if vector, is_vector = json_vector(value); !is_vector {
		return {}, fmt.tprintf("%s: %s must be three numbers", owner, key)
	}
	return vector, nil
}

object_field :: proc(owner, key: string, fields: json.Object) -> (object: json.Object, problem: Problem) {
	value, present := fields[key]
	if !present {
		return nil, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_object: bool
	if object, is_object = value.(json.Object); !is_object {
		return nil, fmt.tprintf("%s: %s must be an object", owner, key)
	}
	return object, nil
}

array_field :: proc(owner, key: string, fields: json.Object) -> (array: json.Array, problem: Problem) {
	value, present := fields[key]
	if !present {
		return nil, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_array: bool
	if array, is_array = value.(json.Array); !is_array {
		return nil, fmt.tprintf("%s: %s must be an array", owner, key)
	}
	return array, nil
}

// The enum value whose name is the text.
name_to_enum :: proc(names: [$E]string, owner, key, text: string) -> (value: E, problem: Problem) {
	for name, candidate in names {
		if name == text {
			return candidate, nil
		}
	}
	return {}, fmt.tprintf("%s: %s %q is unknown", owner, key, text)
}

parse_pieces :: proc(owner: string, fields: json.Object, select: ^Select) -> (problem: Problem) {
	array := array_field(owner, "pieces", fields) or_return
	select.pieces = make([]string, len(array))
	for element, index in array {
		name, is_string := element.(json.String)
		if !is_string {
			return fmt.tprintf("%s: pieces must be an array of strings", owner)
		}
		select.pieces[index] = strings.clone(name)
	}
	return nil
}

parse_strokes :: proc(owner: string, fields: json.Object, select: ^Select) -> (problem: Problem) {
	array := array_field(owner, "strokes", fields) or_return
	select.strokes = make([]Stroke, len(array))
	for element, index in array {
		stroke_owner := fmt.tprintf("%s stroke %d", owner, index)
		stroke_fields, is_object := element.(json.Object)
		if !is_object {
			return fmt.tprintf("%s: must be an object", stroke_owner)
		}
		check_keys(stroke_owner, stroke_fields, {"position", "radius"}) or_return
		select.strokes[index].position = vector_field(stroke_owner, "position", stroke_fields) or_return
		select.strokes[index].radius = number_field(stroke_owner, "radius", stroke_fields) or_return
	}
	return nil
}

SELECT_KINDS := [Select_Kind]string {
	.Pieces  = "pieces",
	.Part    = "part",
	.Box     = "box",
	.Sphere  = "sphere",
	.Strokes = "strokes",
}

// The one kind key the select carries.
select_kind :: proc(owner: string, fields: json.Object) -> (kind: Select_Kind, problem: Problem) {
	found := 0
	for name, candidate in SELECT_KINDS {
		if name in fields {
			kind = candidate
			found += 1
		}
	}
	if found != 1 {
		return {}, fmt.tprintf("%s: needs exactly one of pieces, part, box, sphere and strokes", owner)
	}
	return kind, nil
}

parse_select :: proc(owner: string, value: json.Value, select: ^Select) -> (problem: Problem) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return fmt.tprintf("%s: must be an object", owner)
	}
	check_keys(owner, fields, {"pieces", "part", "box", "sphere", "strokes", "within_part"}) or_return
	select.kind = select_kind(owner, fields) or_return
	if "within_part" in fields {
		select.within_part = strings.clone(string_field(owner, "within_part", fields) or_return)
	}
	switch select.kind {
	case .Pieces:
		return parse_pieces(owner, fields, select)
	case .Part:
		select.part = strings.clone(string_field(owner, "part", fields) or_return)
	case .Box:
		box := object_field(owner, "box", fields) or_return
		box_owner := fmt.tprintf("%s box", owner)
		check_keys(box_owner, box, {"min", "max"}) or_return
		select.minimum = vector_field(box_owner, "min", box) or_return
		select.maximum = vector_field(box_owner, "max", box) or_return
	case .Sphere:
		sphere := object_field(owner, "sphere", fields) or_return
		sphere_owner := fmt.tprintf("%s sphere", owner)
		check_keys(sphere_owner, sphere, {"centre", "radius"}) or_return
		select.centre = vector_field(sphere_owner, "centre", sphere) or_return
		select.radius = number_field(sphere_owner, "radius", sphere) or_return
	case .Strokes:
		return parse_strokes(owner, fields, select)
	}
	return nil
}

// The keys of the step's op; the step's op is already set.
parse_step_keys :: proc(owner: string, fields: json.Object, step: ^Step) -> (problem: Problem) {
	switch step.op {
	case .Import:
	case .Transform:
		front_name := string_field(owner, "front", fields) or_return
		step.front = name_to_enum(FRONT_NAMES, owner, "front", front_name) or_return
		step.height = number_field(owner, "height", fields) or_return
	case .Weld:
		step.metres = number_field(owner, "metres", fields) or_return
	case .Assign:
		step.part = strings.clone(string_field(owner, "part", fields) or_return)
		return parse_select(fmt.tprintf("%s select", owner), fields["select"], &step.select) if "select" in fields else Problem(fmt.tprintf("%s: select missing", owner))
	case .Delete:
		return parse_select(fmt.tprintf("%s select", owner), fields["select"], &step.select) if "select" in fields else Problem(fmt.tprintf("%s: select missing", owner))
	case .Copy:
		step.from = vector_field(owner, "from", fields) or_return
		step.to = vector_field(owner, "to", fields) or_return
		step.turn = integer_field(owner, "turn", fields) or_return
		if step.turn < 0 || step.turn > 3 {
			return fmt.tprintf("%s: turn %d must be 0 to 3", owner, step.turn)
		}
		return parse_select(fmt.tprintf("%s select", owner), fields["select"], &step.select) if "select" in fields else Problem(fmt.tprintf("%s: select missing", owner))
	case .Decimate:
		step.triangles = integer_field(owner, "triangles", fields) or_return
		if step.triangles <= 0 {
			return fmt.tprintf("%s: triangles %d must be 1 or more", owner, step.triangles)
		}
	case .Close:
		step.part = strings.clone(string_field(owner, "part", fields) or_return)
		technique_name := string_field(owner, "technique", fields) or_return
		step.technique = name_to_enum(TECHNIQUE_NAMES, owner, "technique", technique_name) or_return
		step.trim = number_field(owner, "trim", fields) or_return
	}
	return nil
}

parse_step :: proc(owner: string, value: json.Value) -> (step: Step, problem: Problem) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("%s: must be an object", owner)
	}
	op_name, op_problem := string_field(owner, "op", fields)
	if op_problem != nil {
		return {}, op_problem
	}
	if step.op, problem = name_to_enum(OP_NAMES, owner, "op", op_name); problem != nil {
		return {}, problem
	}
	allowed := make([dynamic]string, context.temp_allocator)
	append(&allowed, "op", "note", "enabled")
	append(&allowed, ..OP_KEYS[step.op])
	step.enabled = true
	problem = check_keys(owner, fields, allowed[:])
	if problem == nil && "enabled" in fields {
		enabled, is_boolean := fields["enabled"].(json.Boolean)
		step.enabled = bool(enabled)
		problem = nil if is_boolean else Problem( fmt.tprintf("%s: enabled must be true or false", owner))
	}
	if problem == nil && "note" in fields {
		note: string
		note, problem = string_field(owner, "note", fields)
		step.note = strings.clone(note)
	}
	if problem == nil {
		problem = parse_step_keys(owner, fields, &step)
	}
	if problem != nil {
		step_destroy(&step)
		return {}, problem
	}
	return step, nil
}

// Parses data/machines/<id>/pipeline.sjson. The import step is always
// step 0, added when the file lacks it, and nowhere else. The problem
// names the key and the step index, and lives in context.temp_allocator.
pipeline_parse :: proc(data: []byte) -> (pipeline: Pipeline, problem: string) {
	value, error := json.parse(data, .SJSON, true, context.temp_allocator)
	defer json.destroy_value(value, context.temp_allocator)
	if error != nil {
		return {}, fmt.tprintf("pipeline: not SJSON: %v", error)
	}
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, "pipeline: expected an object"
	}
	if keys_problem, failed := check_keys("pipeline", fields, {"source", "steps"}).?; failed {
		return {}, keys_problem
	}
	source, source_problem := string_field("pipeline", "source", fields)
	if text, failed := source_problem.?; failed {
		return {}, text
	}
	steps, steps_problem := array_field("pipeline", "steps", fields)
	if text, failed := steps_problem.?; failed {
		return {}, text
	}
	pipeline.source = strings.clone(source)
	for element, index in steps {
		step, step_problem := parse_step(fmt.tprintf("step %d", index), element)
		if text, failed := step_problem.?; failed {
			pipeline_destroy(&pipeline)
			return {}, text
		}
		if step.op == .Import && index != 0 {
			pipeline_destroy(&pipeline)
			return {}, fmt.tprintf("step %d: import only as the first step", index)
		}
		append(&pipeline.steps, step)
	}
	if len(pipeline.steps) == 0 || pipeline.steps[0].op != .Import {
		inject_at(&pipeline.steps, 0, Step{op = .Import, enabled = true})
	}
	return pipeline, ""
}

write_vector :: proc(builder: ^strings.Builder, vector: [3]f32) {
	fmt.sbprintf(builder, "[%v, %v, %v]", vector.x, vector.y, vector.z)
}

write_select :: proc(builder: ^strings.Builder, select: Select) {
	strings.write_string(builder, ", select = { ")
	switch select.kind {
	case .Pieces:
		strings.write_string(builder, "pieces = [")
		for piece, index in select.pieces {
			fmt.sbprintf(builder, "%s%q", ", " if index > 0 else "", piece)
		}
		strings.write_string(builder, "]")
	case .Part:
		fmt.sbprintf(builder, "part = %q", select.part)
	case .Box:
		strings.write_string(builder, "box = { min = ")
		write_vector(builder, select.minimum)
		strings.write_string(builder, ", max = ")
		write_vector(builder, select.maximum)
		strings.write_string(builder, " }")
	case .Sphere:
		strings.write_string(builder, "sphere = { centre = ")
		write_vector(builder, select.centre)
		fmt.sbprintf(builder, ", radius = %v }", select.radius)
	case .Strokes:
		// One stroke per line, since a brush paints many.
		strings.write_string(builder, "strokes = [\n")
		for stroke in select.strokes {
			strings.write_string(builder, "\t\t{ position = ")
			write_vector(builder, stroke.position)
			fmt.sbprintf(builder, ", radius = %v }\n", stroke.radius)
		}
		strings.write_string(builder, "\t]")
	}
	if select.within_part != "" {
		fmt.sbprintf(builder, ", within_part = %q", select.within_part)
	}
	strings.write_string(builder, " }")
}

write_step :: proc(builder: ^strings.Builder, step: Step) {
	fmt.sbprintf(builder, "\t{{ op = %q", OP_NAMES[step.op])
	switch step.op {
	case .Import:
	case .Transform:
		fmt.sbprintf(builder, ", front = %q, height = %v", FRONT_NAMES[step.front], step.height)
	case .Weld:
		fmt.sbprintf(builder, ", metres = %v", step.metres)
	case .Assign:
		fmt.sbprintf(builder, ", part = %q", step.part)
		write_select(builder, step.select)
	case .Delete:
		write_select(builder, step.select)
	case .Copy:
		strings.write_string(builder, ", from = ")
		write_vector(builder, step.from)
		strings.write_string(builder, ", to = ")
		write_vector(builder, step.to)
		fmt.sbprintf(builder, ", turn = %d", step.turn)
		write_select(builder, step.select)
	case .Decimate:
		fmt.sbprintf(builder, ", triangles = %d", step.triangles)
	case .Close:
		fmt.sbprintf(builder, ", part = %q, technique = %q, trim = %v", step.part, TECHNIQUE_NAMES[step.technique], step.trim)
	}
	if !step.enabled {
		strings.write_string(builder, ", enabled = false")
	}
	if step.note != "" {
		fmt.sbprintf(builder, ", note = %q", step.note)
	}
	strings.write_string(builder, " }\n")
}

// The pipeline as SJSON in the format of doc/workflows/pipeline_editor.md,
// one step per line, a select's strokes one per line within it. The
// import step is written too.
pipeline_save :: proc(pipeline: Pipeline, allocator := context.allocator) -> string {
	builder := strings.builder_make(allocator)
	fmt.sbprintf(&builder, "source = %q\nsteps = [\n", pipeline.source)
	for step in pipeline.steps {
		write_step(&builder, step)
	}
	strings.write_string(&builder, "]\n")
	return strings.to_string(builder)
}
