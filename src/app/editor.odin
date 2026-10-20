package app

// The pipeline editor (doc/workflows/pipeline_editor.md, The editor): an
// asset's steps listed on the left, up to four step views in a grid on the
// right under one orbit camera, each part of a view in a palette colour or
// in the material the asset's brief names for it.

import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:slice"
import engine "../engine"
import pipeline "../pipeline"

EDITOR_VIEWS_MAXIMUM :: 4
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

// The renderer's scene: the camera's start, the light and the floor slab
// every view shares. The slab is the scene's first item.
EDITOR_SCENE :: `
camera = { mode = "orbit", target = [0, 0.5, 0], yaw = 0.6, pitch = 0.35, distance = 2.6 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
ambient = 0.15
items = [
	{ shape = "box", size = [3, 0.1, 3], position = [0, -0.05, 0], material = "concrete" }
]
`

// One part of a view, uploaded as one mesh. colour_index is the part's
// index into the palette, -1 for triangles of no part.
Editor_Part_Mesh :: struct {
	mesh:         engine.Mesh_Id,
	half_extents: [3]f32,
	colour_index: int,
	material:     engine.Material_Id,
}

// What a view's meshes were built from. The view rebuilds when the step's
// key differs from it.
Editor_Upload_Key :: struct {
	generation: int,
	triangles:  int,
	present:    bool,
}

Editor_Upload :: struct {
	step:   int,
	key:    Editor_Upload_Key,
	built:  bool,
	meshes: [dynamic]Editor_Part_Mesh,
}

Editor_Brief_Part :: struct {
	name, material: string,
}

Editor :: struct {
	machine:       string,
	pipeline_path: string,
	run:           pipeline.Run,
	// The renderer, the material library, the light and the slab.
	scene:         engine.Scene_View,
	brief_parts:   [dynamic]Editor_Brief_Part,
	selected:      int,
	// Step indices in pipeline order, at most EDITOR_VIEWS_MAXIMUM.
	shown:         [dynamic]int,
	// One per shown step, in the same order.
	uploads:       [dynamic]Editor_Upload,
	orbit:         engine.Orbit,
	false_colour:  bool,
	// Raised by every editor_run_from. generations[n] is its value at the
	// last rerun that reached step n, so a view of a step rerun rebuilds.
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

// Needs a current GL context. Reads data/machines/<machine>/pipeline.sjson
// and brief.sjson under the working directory, the project root, and runs
// the native steps.
editor_open :: proc(editor: ^Editor, machine: string, aspect: f32) -> (problem: string) {
	root, root_error := os.get_working_directory(context.allocator)
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
	editor.orbit = editor.scene.orbit
	editor.false_colour = true
	editor.selected = max(len(editor.run.pipeline.steps) - 1, 0)
	editor.shown = editor_default_shown(len(editor.run.pipeline.steps))
	editor_sync_uploads(editor)
	return ""
}

editor_destroy :: proc(editor: ^Editor) {
	for &upload in editor.uploads do delete(upload.meshes)
	delete(editor.uploads)
	delete(editor.shown)
	delete(editor.generations)
	delete(editor.message)
	delete(editor.brush.counts)
	for part in editor.brief_parts {
		delete(part.name)
		delete(part.material)
	}
	delete(editor.brief_parts)
	engine.draw_list_destroy(&editor.draw_list)
	pipeline.run_destroy(&editor.run)
	// Frees the GL meshes of the uploads with the renderer.
	engine.scene_view_destroy(&editor.scene)
	delete(editor.pipeline_path)
	editor^ = {}
}

// Every rerun goes through here, so the views of the steps it drops rebuild.
// Call it after any change of the steps, with the first step changed.
editor_run_from :: proc(editor: ^Editor, index: int) {
	editor.generation += 1
	resize(&editor.generations, len(editor.run.pipeline.steps))
	for &generation in editor.generations[clamp(index, 0, len(editor.generations)):] do generation = editor.generation
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

// Up to four steps spread evenly from the first to the last.
editor_default_shown :: proc(step_count: int) -> (shown: [dynamic]int) {
	if step_count == 0 do return
	for slot in 0 ..< EDITOR_VIEWS_MAXIMUM {
		index := slot * (step_count - 1) / (EDITOR_VIEWS_MAXIMUM - 1)
		if len(shown) == 0 || shown[len(shown) - 1] != index do append(&shown, index)
	}
	return
}

// The step joins the grid in pipeline order, unless it is shown or the grid is full.
editor_shown_add :: proc(shown: ^[dynamic]int, step: int) {
	if len(shown) >= EDITOR_VIEWS_MAXIMUM || slice.contains(shown[:], step) do return
	position := 0
	for position < len(shown) && shown[position] < step do position += 1
	inject_at(shown, position, step)
}

editor_shown_drop :: proc(shown: ^[dynamic]int, step: int) {
	if position, found := slice.linear_search(shown[:], step); found do ordered_remove(shown, position)
}

// The uploads follow shown: a step still shown keeps its upload, a new one
// gets an empty upload, a dropped one's meshes are released.
editor_sync_uploads :: proc(editor: ^Editor) {
	kept := make([dynamic]Editor_Upload, 0, len(editor.shown))
	for step in editor.shown {
		upload := Editor_Upload{step = step}
		for &old in editor.uploads {
			if old.step == step {
				upload = old
				old.step = -1
				break
			}
		}
		append(&kept, upload)
	}
	for &old in editor.uploads {
		if old.step < 0 do continue
		editor_release_upload(editor, &old)
		delete(old.meshes)
	}
	delete(editor.uploads)
	editor.uploads = kept
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

// Rebuilds the meshes of each view whose step changed since it was built.
editor_refresh_uploads :: proc(editor: ^Editor) {
	for &upload in editor.uploads {
		key := editor_upload_key(editor, upload.step)
		if upload.built && upload.key == key do continue
		editor_release_upload(editor, &upload)
		upload.key = key
		upload.built = true
		if key.present do editor_build_upload(editor, &upload, editor.run.outputs[upload.step])
	}
}

editor_build_upload :: proc(editor: ^Editor, upload: ^Editor_Upload, mesh: pipeline.Pipeline_Mesh) {
	buckets := editor_part_triangles(mesh)
	defer {
		for bucket in buckets do delete(bucket)
		delete(buckets)
	}
	for bucket, part in buckets {
		if len(bucket) == 0 do continue
		data := editor_mesh_data(mesh, bucket[:])
		defer engine.mesh_data_destroy(&data)
		colour_index := part if part < len(mesh.part_names) else -1
		append(&upload.meshes, Editor_Part_Mesh {
			mesh = engine.gl_renderer_upload_mesh(&editor.scene.renderer, data),
			half_extents = engine.mesh_half_extents(data),
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

// The triangles as a mesh of their own, holding each vertex they use once.
editor_mesh_data :: proc(mesh: pipeline.Pipeline_Mesh, triangles: []int) -> (data: engine.Mesh_Data) {
	remap := make([]u32, len(mesh.positions))
	defer delete(remap)
	slice.fill(remap, max(u32))
	vertices := make([dynamic]engine.Vertex)
	indices := make([]u32, 3 * len(triangles))
	for triangle, position in triangles {
		for corner in 0 ..< 3 {
			vertex := mesh.triangles[triangle][corner]
			if remap[vertex] == max(u32) {
				remap[vertex] = u32(len(vertices))
				normal := mesh.normals[vertex] if int(vertex) < len(mesh.normals) else [3]f32{0, 1, 0}
				append(&vertices, engine.Vertex{position = mesh.positions[vertex], normal = normal})
			}
			indices[3 * position + corner] = remap[vertex]
		}
	}
	return {vertices = vertices[:], indices = indices}
}

// The palette colour with the false colour material's albedo divided out,
// grey for triangles of no part.
editor_false_colour_tint :: proc(colour_index: int, albedo: [3]f32) -> [3]f32 {
	colour := EDITOR_PART_NONE_COLOUR
	if colour_index >= 0 do colour = EDITOR_PALETTE[colour_index % len(EDITOR_PALETTE)]
	return colour / linalg.max(albedo, [3]f32{0.01, 0.01, 0.01})
}

// One view's scene: the slab, then each part in false colour or its material.
editor_fill_draw_list :: proc(editor: ^Editor, upload: Editor_Upload) {
	list := &editor.draw_list
	engine.draw_list_clear(list)
	scene := editor.scene.scene
	list.camera = engine.orbit_camera(editor.orbit, engine.SCENE_VIEW_VERTICAL_FOV, engine.SCENE_VIEW_NEAR, 100)
	list.sun = scene.sun
	list.exposure = scene.exposure
	list.sky_colour = scene.sky_colour
	list.ground_colour = scene.ground_colour
	slab := scene.items[0]
	engine.draw_list_add(list, editor.scene.item_mesh_ids[0], slab.material, linalg.matrix4_translate_f32(slab.position), editor.scene.item_half_extents[0])
	list.items[len(list.items) - 1].tint = {1, 1, 1}
	false_colour, _ := engine.material_id_by_name(editor.scene.library, EDITOR_FALSE_COLOUR_MATERIAL)
	albedo := editor.scene.library.materials[false_colour].albedo
	for part in upload.meshes {
		material, tint := part.material, [3]f32{1, 1, 1}
		if editor.false_colour do material, tint = false_colour, editor_false_colour_tint(part.colour_index, albedo)
		engine.draw_list_add(list, part.mesh, material, linalg.MATRIX4F32_IDENTITY, part.half_extents)
		list.items[len(list.items) - 1].tint = tint
	}
}
