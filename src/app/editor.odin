package app

// The pipeline editor (doc/workflows/pipeline_editor.md, The editor): an
// asset's steps as a line of machines on a concrete floor, machine n the
// output of step n standing at x = n * EDITOR_MACHINE_SPACING, walked
// along with a fly camera. Each part of a machine is drawn in a palette
// colour or in the material the asset's brief names for it.

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:strings"
import engine "../engine"
import pipeline "../pipeline"

// Metres between two machines along x.
EDITOR_MACHINE_SPACING :: f32(2)
// A geometry's vertices and the index lists of every machine sharing it
// are uploaded when the camera comes within the first distance of the
// middle of one of those machines and released beyond the second.
EDITOR_UPLOAD_DISTANCE :: f32(12)
EDITOR_RELEASE_DISTANCE :: f32(20)
// Scales the colour of a disabled step's machine.
EDITOR_DISABLED_TINT :: f32(0.35)
EDITOR_WAITING_COLOUR :: [3]f32{0.55, 0.55, 0.55}
EDITOR_FAILED_COLOUR :: [3]f32{0.85, 0.15, 0.12}
// The box of a machine before any step has an output.
EDITOR_DEFAULT_BOUNDS :: Editor_Bounds{{-0.5, 0, -0.5}, {0.5, 1, 0.5}}
// The floor reaches this far past the first and the last machine and to each side.
EDITOR_FLOOR_MARGIN :: f32(2)
EDITOR_FLOOR_THICKNESS :: f32(0.1)
// raylib reports the cursor's jump to the window's middle as one movement
// in the first frames, which would turn the start view away.
EDITOR_MOUSE_SETTLE_FRAMES :: 3
// Metres per second the fly walks, slower than the demos' for close work on a one metre machine.
EDITOR_FLY_SPEED :: f32(2)
// The camera's start beside machine 0, looking down the line.
EDITOR_START_POSITION :: [3]f32{-1.6, 1.4, 1.9}
EDITOR_START_TARGET :: [3]f32{2 * EDITOR_MACHINE_SPACING, 0.4, 0}
// The material false colour is drawn in, untextured and without wear, its
// albedo divided out of the tint so a part shows the palette colour itself.
EDITOR_FALSE_COLOUR_MATERIAL :: "concrete"
EDITOR_PART_NONE_COLOUR :: [3]f32{0.5, 0.5, 0.5}
// One colour per part index, cycled past the last.
EDITOR_PALETTE := [?][3]f32 {
	{0.90, 0.22, 0.18},
	{0.18, 0.60, 0.95},
	{0.95, 0.80, 0.12},
	{0.30, 0.80, 0.28},
	{0.80, 0.32, 0.88},
	{0.98, 0.52, 0.12},
	{0.15, 0.85, 0.80},
	{0.95, 0.45, 0.65},
	{0.55, 0.45, 0.98},
	{0.65, 0.88, 0.20},
}

// The renderer's scene: the light the line stands in. The floor and the
// machines are the editor's own meshes, the camera its own fly.
EDITOR_SCENE :: `
camera = { mode = "fly", target = [0, 0.5, 0], yaw = 0, pitch = 0, distance = 2 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
ambient = 0.15
items = []
`

// One part of a machine, uploaded as one mesh. colour_index is the part's
// index into the palette, -1 for triangles of no part.
Editor_Part_Mesh :: struct {
	mesh:         engine.Mesh_Id,
	half_extents: [3]f32,
	colour_index: int,
	material:     engine.Material_Id,
}

// What a machine's meshes and bounds were built from. They rebuild when
// the step's key differs from it.
Editor_Upload_Key :: struct {
	generation: int,
	triangles:  int,
	present:    bool,
}

// A machine's index lists, one mesh per part, drawn against the vertices
// of the geometry it shares (the mesh vertices names).
Editor_Upload :: struct {
	key:      Editor_Upload_Key,
	vertices: engine.Mesh_Id,
	built:    bool,
	meshes:   [dynamic]Editor_Part_Mesh,
}

// The vertices of a geometry, held by the machine of the step that owns it
// (pipeline.Run's owners).
Editor_Vertices :: struct {
	key:   Editor_Upload_Key,
	mesh:  engine.Mesh_Id,
	built: bool,
}

// An axis aligned box in a machine's own frame, or in the world.
Editor_Bounds :: struct {
	minimum, maximum: [3]f32,
}

// One per step. near is whether the camera is within upload range of it
// alone; bounds is the box of the step's output, or of the machine before
// it while the step has none.
Editor_Machine :: struct {
	upload:       Editor_Upload,
	vertices:     Editor_Vertices,
	near:         bool,
	bounds:       Editor_Bounds,
	bounds_key:   Editor_Upload_Key,
	bounds_known: bool,
}

Editor_Brief_Part :: struct {
	name, material: string,
}

Editor :: struct {
	machine:       string,
	pipeline_path: string,
	run:           pipeline.Run,
	// The renderer, the material library and the light.
	scene:         engine.Scene_View,
	brief_parts:   [dynamic]Editor_Brief_Part,
	// The step under the crosshair, else the one nearest the camera.
	selected:      int,
	// One per step, in pipeline order.
	machines:      [dynamic]Editor_Machine,
	fly:           engine.Fly,
	// A unit box, scaled for the floor and the boxes of steps without output.
	box_mesh:      engine.Mesh_Id,
	false_colour:  bool,
	list_open:     bool,
	// Frames stepped since the editor opened; the mouse turns the camera
	// only after EDITOR_MOUSE_SETTLE_FRAMES.
	frames:        int,
	// Raised by every editor_run_from. generations[n] is its value at the
	// last rerun that reached step n, so the machine of a step rerun rebuilds.
	generation:    int,
	generations:   [dynamic]int,
	draw_list:     engine.Draw_List,
	// Set by every edit, cleared by a save. A first leave with unsaved
	// edits only warns.
	unsaved:       bool,
	leave_warned:  bool,
	// The header's last line: a warning, a save's result. Owned.
	message:       string,
	panel_open:    bool,
	panel_row:     int,
	op_menu_open:  bool,
	op_menu_row:   int,
	brush:         Editor_Brush,
}

// The project the pipeline's paths hang off: BEDROCK_ARRAY_ROOT, which the
// launcher sets since it runs the play build from its own directory, else
// the working directory (a build run from the checkout).
editor_project_root :: proc() -> (string, os.Error) {
	if root := os.get_env("BEDROCK_ARRAY_ROOT", context.temp_allocator); root != "" {
		return strings.clone(root), nil
	}
	return os.get_working_directory(context.allocator)
}

// Needs a current GL context. Reads data/machines/<machine>/pipeline.sjson
// and brief.sjson under the project root and runs the native steps.
editor_open :: proc(editor: ^Editor, machine: string, aspect: f32) -> (problem: string) {
	root, root_error := editor_project_root()
	defer delete(root)
	if root_error != nil do return fmt.tprintf("the working directory: %v", root_error)
	scene_data := EDITOR_SCENE
	problem = engine.scene_view_init(&editor.scene, MATERIAL_LIBRARY, transmute([]byte)scene_data, material_textures, nil, aspect)
	if problem != "" do return problem
	editor.machine = machine
	editor.pipeline_path = fmt.aprintf("%s/data/machines/%s/pipeline.sjson", root, machine)
	data, read_error := os.read_entire_file_from_path(editor.pipeline_path, context.allocator)
	defer delete(data)
	if read_error != nil do return fmt.tprintf("%s: %v", editor.pipeline_path, read_error)
	parsed, parse_problem := pipeline.pipeline_parse(data)
	if parse_problem != "" do return fmt.tprintf("%s: %s", editor.pipeline_path, parse_problem)
	editor.brief_parts = editor_read_brief(fmt.tprintf("%s/data/machines/%s/brief.sjson", root, machine))
	editor.brush.radius = EDITOR_BRUSH_RADIUS_DEFAULT
	editor.run = pipeline.run_make(parsed, root, machine)
	editor_run_from(editor, 0)
	box := engine.box_mesh({1, 1, 1})
	defer engine.mesh_data_destroy(&box)
	editor.box_mesh = engine.gl_renderer_upload_mesh(&editor.scene.renderer, box)
	editor.fly = editor_fly_looking_at(EDITOR_START_POSITION, EDITOR_START_TARGET)
	editor.false_colour = true
	editor.list_open = true
	editor_sync_machines(editor)
	return ""
}

// A fly at the position looking at the target.
editor_fly_looking_at :: proc(position, target: [3]f32) -> engine.Fly {
	direction := linalg.normalize(target - position)
	return {position = position, yaw = math.atan2(-direction.x, -direction.z), pitch = math.asin(-direction.y)}
}

editor_destroy :: proc(editor: ^Editor) {
	// The GL meshes go with the renderer below.
	for &machine in editor.machines do delete(machine.upload.meshes)
	delete(editor.machines)
	delete(editor.generations)
	delete(editor.message)
	delete(editor.brush.counts)
	editor_drop_brush_grid(&editor.brush)
	for part in editor.brief_parts {
		delete(part.name)
		delete(part.material)
	}
	delete(editor.brief_parts)
	engine.draw_list_destroy(&editor.draw_list)
	pipeline.run_destroy(&editor.run)
	// Frees the GL meshes of the machines and the box with the renderer.
	engine.scene_view_destroy(&editor.scene)
	delete(editor.pipeline_path)
	editor^ = {}
}

// Every rerun goes through here, so the machines of the steps it drops rebuild.
// Call it after any change of the steps, with the first step changed.
editor_run_from :: proc(editor: ^Editor, index: int) {
	editor.generation += 1
	resize(&editor.generations, len(editor.run.pipeline.steps))
	for &generation in editor.generations[clamp(index, 0, len(editor.generations)):] do generation = editor.generation
	if editor.brush.grid_built && editor.brush.grid_key[0] >= index do editor_drop_brush_grid(&editor.brush)
	pipeline.run_from(&editor.run, index)
}

// The steps' part names from the brief, in its order, valid until the
// brief changes.
editor_part_names :: proc(editor: ^Editor) -> []string {
	names := make([]string, len(editor.brief_parts), context.temp_allocator)
	for part, index in editor.brief_parts do names[index] = part.name
	return names
}

// The parts' names and materials, none when the brief is missing or
// malformed: the editor still runs, the parts then drawn in the false
// colour material.
editor_read_brief :: proc(path: string) -> (parts: [dynamic]Editor_Brief_Part) {
	data, error := os.read_entire_file_from_path(path, context.allocator)
	defer delete(data)
	if error != nil do return
	return editor_parse_brief_parts(data)
}

// parts[].name and parts[].material of a brief, owned by the caller.
editor_parse_brief_parts :: proc(data: []byte) -> (parts: [dynamic]Editor_Brief_Part) {
	value, error := json.parse(data, .SJSON, true, context.temp_allocator)
	defer json.destroy_value(value, context.temp_allocator)
	if error != nil do return
	root, is_object := value.(json.Object)
	if !is_object do return
	list, is_array := root["parts"].(json.Array)
	if !is_array do return
	for entry in list {
		fields := entry.(json.Object) or_continue
		name := fields["name"].(json.String) or_continue
		material := fields["material"].(json.String) or_continue
		append(&parts, Editor_Brief_Part{fmt.aprint(name), fmt.aprint(material)})
	}
	return
}

editor_brief_material :: proc(parts: []Editor_Brief_Part, part_name: string) -> (string, bool) {
	for part in parts {
		if part.name == part_name do return part.material, true
	}
	return "", false
}

// The machines follow the steps: one per step, each with its bounds. A
// geometry is wanted while the camera is near any machine sharing it;
// then its vertices and every sharing machine's index lists are uploaded,
// rebuilt when their step changed, and released when it is no longer
// wanted. Index lists go before the vertices they draw from.
editor_sync_machines :: proc(editor: ^Editor) {
	old_count := len(editor.machines)
	resize(&editor.machines, len(editor.run.pipeline.steps))
	for &machine in editor.machines[min(old_count, len(editor.machines)):] do machine = {}
	for &machine, index in editor.machines {
		editor_refresh_bounds(editor, index)
		centre := editor_machine_offset(index) + (machine.bounds.minimum + machine.bounds.maximum) / 2
		machine.near = editor_keep_near(machine.near, linalg.length(centre - editor.fly.position))
	}
	owners := editor_geometry_owners(editor.run, len(editor.machines))
	wanted := editor_wanted_geometries(editor.machines[:], owners)
	for index in 0 ..< len(editor.machines) {
		if !editor_upload_current(editor, index, owners[index], wanted) do editor_drop_upload(editor, index)
	}
	for index in 0 ..< len(editor.machines) do editor_refresh_vertices(editor, index, owners[index] == index && wanted[index])
	for index in 0 ..< len(editor.machines) {
		if wanted[owners[index]] && !editor.machines[index].upload.built do editor_build_machine(editor, index, owners[index])
	}
}

// The step owning each machine's geometry, the machine itself while its
// step has no output.
editor_geometry_owners :: proc(run: pipeline.Run, count: int) -> []int {
	owners := make([]int, count, context.temp_allocator)
	for &owner, index in owners do owner = run.owners[index] if index < len(run.owners) else index
	return owners
}

// wanted[n] is whether any machine sharing step n's geometry is near.
editor_wanted_geometries :: proc(machines: []Editor_Machine, owners: []int) -> []bool {
	wanted := make([]bool, len(machines), context.temp_allocator)
	for machine, index in machines do wanted[owners[index]] ||= machine.near
	return wanted
}

// Whether the machine's index lists are built for its step as it is now,
// against its owner's vertices as they are now, and still wanted.
editor_upload_current :: proc(editor: ^Editor, index, owner: int, wanted: []bool) -> bool {
	upload := editor.machines[index].upload
	vertices := editor.machines[owner].vertices
	if !upload.built || !wanted[owner] || upload.key != editor_upload_key(editor, index) do return false
	if !upload.key.present do return true
	return vertices.built && vertices.key == editor_upload_key(editor, owner) && upload.vertices == vertices.mesh
}

editor_drop_upload :: proc(editor: ^Editor, index: int) {
	upload := &editor.machines[index].upload
	editor_release_upload(editor, upload)
	upload.built = false
}

// Uploads the vertices of the step's own geometry when kept, after
// releasing them when they are not kept or are of an older output.
editor_refresh_vertices :: proc(editor: ^Editor, index: int, kept: bool) {
	vertices := &editor.machines[index].vertices
	key := editor_upload_key(editor, index)
	if vertices.built && (!kept || vertices.key != key) {
		engine.gl_renderer_release_mesh(&editor.scene.renderer, vertices.mesh)
		vertices.built = false
	}
	if !kept || !key.present || vertices.built do return
	data := editor_vertices(editor.run.outputs[index])
	defer delete(data)
	vertices^ = {key = key, mesh = engine.gl_renderer_upload_vertices(&editor.scene.renderer, data), built = true}
}

// The machine's index lists against its owner's vertices.
editor_build_machine :: proc(editor: ^Editor, index, owner: int) {
	upload := &editor.machines[index].upload
	upload.key = editor_upload_key(editor, index)
	upload.built = true
	upload.vertices = editor.machines[owner].vertices.mesh
	if upload.key.present && editor.machines[owner].vertices.built do editor_build_upload(editor, upload, editor.run.outputs[index])
}

// Where machine n stands: its own frame's origin in the world.
editor_machine_offset :: proc(index: int) -> [3]f32 {
	return {f32(index) * EDITOR_MACHINE_SPACING, 0, 0}
}

// Within range a machine comes near at the upload distance and stays near
// up to the release distance, so it is not uploaded and released by turns.
editor_keep_near :: proc(near: bool, distance: f32) -> bool {
	if near do return distance <= EDITOR_RELEASE_DISTANCE
	return distance < EDITOR_UPLOAD_DISTANCE
}

// The box round the vertices the triangles use, the default box for none.
editor_mesh_bounds :: proc(mesh: pipeline.Pipeline_Mesh) -> Editor_Bounds {
	if len(mesh.triangles) == 0 do return EDITOR_DEFAULT_BOUNDS
	bounds := Editor_Bounds{max(f32), min(f32)}
	for corners in mesh.triangles {
		for vertex in corners {
			bounds.minimum = linalg.min(bounds.minimum, mesh.positions[vertex])
			bounds.maximum = linalg.max(bounds.maximum, mesh.positions[vertex])
		}
	}
	return bounds
}

// A step with output takes its output's box, once per change; one without
// takes the box of the machine before it, every frame, since that may change.
editor_refresh_bounds :: proc(editor: ^Editor, index: int) {
	machine := &editor.machines[index]
	key := editor_upload_key(editor, index)
	if machine.bounds_known && machine.bounds_key == key do return
	machine.bounds_key = key
	machine.bounds_known = key.present
	if key.present do machine.bounds = editor_mesh_bounds(editor.run.outputs[index])
	else do machine.bounds = editor.machines[index - 1].bounds if index > 0 else EDITOR_DEFAULT_BOUNDS
}

// Machine n's bounds moved to where it stands.
editor_world_bounds :: proc(bounds: Editor_Bounds, index: int) -> Editor_Bounds {
	offset := editor_machine_offset(index)
	return {bounds.minimum + offset, bounds.maximum + offset}
}

editor_release_upload :: proc(editor: ^Editor, upload: ^Editor_Upload) {
	for part in upload.meshes do engine.gl_renderer_release_mesh(&editor.scene.renderer, part.mesh)
	clear(&upload.meshes)
}

editor_upload_key :: proc(editor: ^Editor, step: int) -> Editor_Upload_Key {
	generation := editor.generations[step] if step < len(editor.generations) else editor.generation
	if step >= len(editor.run.outputs) do return {generation = generation}
	return {generation = generation, triangles = len(editor.run.outputs[step].triangles), present = true}
}

editor_build_upload :: proc(editor: ^Editor, upload: ^Editor_Upload, mesh: pipeline.Pipeline_Mesh) {
	buckets := editor_part_triangles(mesh)
	defer {
		for bucket in buckets do delete(bucket)
		delete(buckets)
	}
	for bucket, part in buckets {
		if len(bucket) == 0 do continue
		indices, half_extents := editor_part_indices(mesh, bucket[:])
		defer delete(indices)
		colour_index := part if part < len(mesh.part_names) else -1
		append(&upload.meshes, Editor_Part_Mesh {
			mesh = engine.gl_renderer_upload_indices(&editor.scene.renderer, upload.vertices, indices),
			half_extents = half_extents,
			colour_index = colour_index,
			material = editor_part_material(editor, mesh, colour_index),
		})
	}
}

// The brief's material for the part, the false colour material for a part
// it does not name and for triangles of no part.
editor_part_material :: proc(editor: ^Editor, mesh: pipeline.Pipeline_Mesh, colour_index: int) -> engine.Material_Id {
	fallback, _ := engine.material_id_by_name(editor.scene.library, EDITOR_FALSE_COLOUR_MATERIAL)
	if colour_index < 0 do return fallback
	name, named := editor_brief_material(editor.brief_parts[:], mesh.part_names[colour_index])
	if !named do return fallback
	material, found := engine.material_id_by_name(editor.scene.library, name)
	return material if found else fallback
}

// The triangle indices of each part, by part index, then one more list for
// the triangles of no part.
editor_part_triangles :: proc(mesh: pipeline.Pipeline_Mesh) -> [][dynamic]int {
	buckets := make([][dynamic]int, len(mesh.part_names) + 1)
	for part, triangle in mesh.parts {
		slot := int(part) if int(part) < len(mesh.part_names) else len(mesh.part_names)
		append(&buckets[slot], triangle)
	}
	return buckets
}

// Every vertex of the mesh, for one upload its sharing steps draw from.
editor_vertices :: proc(mesh: pipeline.Pipeline_Mesh) -> []engine.Vertex {
	vertices := make([]engine.Vertex, len(mesh.positions))
	for &vertex, index in vertices {
		normal := mesh.normals[index] if index < len(mesh.normals) else [3]f32{0, 1, 0}
		vertex = {position = mesh.positions[index], normal = normal}
	}
	return vertices
}

// The triangles' corners as indices into the mesh's vertices, and the half
// extents about the origin of the vertices they use, for the wear rule.
editor_part_indices :: proc(mesh: pipeline.Pipeline_Mesh, triangles: []int) -> (indices: []u32, half_extents: [3]f32) {
	indices = make([]u32, 3 * len(triangles))
	for triangle, position in triangles {
		for corner in 0 ..< 3 {
			vertex := mesh.triangles[triangle][corner]
			indices[3 * position + corner] = vertex
			half_extents = linalg.max(half_extents, linalg.abs(mesh.positions[vertex]))
		}
	}
	return
}

// The palette colour with the false colour material's albedo divided out,
// grey for triangles of no part.
editor_false_colour_tint :: proc(colour_index: int, albedo: [3]f32) -> [3]f32 {
	colour := EDITOR_PART_NONE_COLOUR
	if colour_index >= 0 do colour = EDITOR_PALETTE[colour_index % len(EDITOR_PALETTE)]
	return colour / linalg.max(albedo, [3]f32{0.01, 0.01, 0.01})
}


// The tint of a step's machine: dimmed when the step is disabled.
editor_machine_dim :: proc(step: pipeline.Step) -> f32 {
	return 1 if step.enabled else EDITOR_DISABLED_TINT
}

// The scene: the floor under the whole line, then each machine near the
// camera, its parts in false colour or their materials, or a box of its
// bounds while its step has no output, red when the step failed. A machine
// uploaded only because it shares a near geometry is not drawn.
editor_fill_draw_list :: proc(editor: ^Editor) {
	list := &editor.draw_list
	engine.draw_list_clear(list)
	scene := editor.scene.scene
	list.camera = editor_camera(editor)
	list.sun = scene.sun
	list.exposure = scene.exposure
	list.sky_colour = scene.sky_colour
	list.ground_colour = scene.ground_colour
	false_colour, _ := engine.material_id_by_name(editor.scene.library, EDITOR_FALSE_COLOUR_MATERIAL)
	albedo := editor.scene.library.materials[false_colour].albedo
	floor := editor_floor_bounds(len(editor.machines))
	editor_add_box(list, editor.box_mesh, false_colour, floor, {1, 1, 1})
	for machine, index in editor.machines {
		dim := editor_machine_dim(editor.run.pipeline.steps[index])
		if !machine.upload.key.present || !machine.upload.built || !machine.near {
			if machine.bounds_key.present do continue
			colour := EDITOR_FAILED_COLOUR if editor.run.status[index].state == .Failed else EDITOR_WAITING_COLOUR
			editor_add_box(list, editor.box_mesh, false_colour, editor_world_bounds(machine.bounds, index), colour / linalg.max(albedo, [3]f32{0.01, 0.01, 0.01}) * dim)
			continue
		}
		transform := linalg.matrix4_translate_f32(editor_machine_offset(index))
		for part in machine.upload.meshes {
			material, tint := part.material, [3]f32{1, 1, 1}
			if editor.false_colour do material, tint = false_colour, editor_false_colour_tint(part.colour_index, albedo)
			engine.draw_list_add(list, part.mesh, material, transform, part.half_extents)
			list.items[len(list.items) - 1].tint = tint * dim
		}
	}
}

// The floor's box, its top at y 0.
editor_floor_bounds :: proc(machine_count: int) -> Editor_Bounds {
	last := editor_machine_offset(max(machine_count - 1, 0)).x
	margin := EDITOR_FLOOR_MARGIN
	return {{-margin, -EDITOR_FLOOR_THICKNESS, -margin}, {last + margin, 0, margin}}
}

// The unit box stretched over the bounds.
editor_add_box :: proc(list: ^engine.Draw_List, box: engine.Mesh_Id, material: engine.Material_Id, bounds: Editor_Bounds, tint: [3]f32) {
	size := linalg.max(bounds.maximum - bounds.minimum, [3]f32{1e-3, 1e-3, 1e-3})
	transform := linalg.matrix4_translate_f32((bounds.minimum + bounds.maximum) / 2) * linalg.matrix4_scale_f32(size)
	engine.draw_list_add(list, box, material, transform, size / 2)
	list.items[len(list.items) - 1].tint = tint
}
