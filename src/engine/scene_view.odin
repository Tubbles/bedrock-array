package engine

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"

SCENE_VIEW_DISTANCE_MAXIMUM :: f32(30) // Enough for the models page's row on a phone in portrait.
SCENE_VIEW_VERTICAL_FOV :: f32(math.PI / 3)
// Metres per second a held key or the stick walks the fly.
SCENE_VIEW_FLY_SPEED :: f32(5)
SCENE_VIEW_STEP_LIMIT :: f32(0.1)
SCENE_VIEW_DISTANCE_MINIMUM :: f32(1)
// Radians per second a held key or the stick turns the orbit.
SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND :: f32(2)
// Zoom per second a held key or the stick applies, the distance scaled by exp(-zoom).
SCENE_VIEW_ZOOM_PER_SECOND :: f32(1)

// One frame's input: walk per axis (right, up, forward), each from minus one to one, turn in radians (yaw, pitch), already scaled by the caller, and cycle_configuration, previous_configuration and focus_step the edges of the presses the caller detects. In orbit mode walk and turn go round the target and walk.z zooms.
Scene_Input :: struct {
	walk:                [3]f32,
	turn:                [2]f32,
	// Metres in the fly's frame (right, up, forward), applied as given with no speed or frame time, for a gesture that already measured its distance.
	move:                   [3]f32,
	// Applied as given in orbit mode, the distance scaled by exp(-zoom).
	zoom:                   f32,
	cycle_configuration:    bool,
	previous_configuration: bool,
	// Minus one, zero or one: in orbit mode the orbit moves to the previous or next mesh item.
	focus_step:             int,
}

// An item's levels of detail, finest first, with each level's triangle count, the finest level's half extents and the level drawn now.
Scene_Item_Levels :: struct {
	mesh_ids:        []Mesh_Id,
	triangle_counts: []int,
	half_extents:    [3]f32,
	current:         int,
}

// A scene drawn from its data through the fly or the orbit camera, by the scene's camera mode, with no window or canvas of its own. The item arrays hold one entry per item and configuration, at item_index * count + configuration, item_levels one per item, empty for an item without levels.
Scene_View :: struct {
	library:           Material_Library,
	scene:             Scene,
	renderer:          Gl_Renderer,
	item_mesh_ids:     []Mesh_Id,
	item_half_extents: [][3]f32,
	item_levels:       []Scene_Item_Levels,
	lod:               Lod_Settings,
	draw_list:         Draw_List,
	fly:               Fly,
	orbit:             Orbit,
	configuration:     int,
	// The index into scene.items of the orbited item, and the camera target's offset from the item focused at init.
	focus:             int,
	focus_offset:      [3]f32,
}

// Needs a current GL context; the aspect fits the start view.
scene_view_init :: proc(view: ^Scene_View, library_data, scene_data: []byte, textures, meshes: []runtime.Load_Directory_File, aspect: f32) -> (problem: string) {
	view.library, problem = parse_material_library(library_data)
	if problem != "" do return fmt.tprintf("material library: %s", problem)
	view.scene, problem = parse_scene(scene_data, view.library)
	if problem != "" do return fmt.tprintf("scene: %s", problem)
	view.lod = view.scene.lod
	view.orbit = orbit_fit_width(view.scene.camera, view.scene.fit_width, SCENE_VIEW_VERTICAL_FOV, aspect, SCENE_VIEW_DISTANCE_MAXIMUM)
	view.fly = fly_from_orbit(view.orbit)
	view.focus = scene_nearest_mesh_item(view.scene.items, view.scene.camera.target)
	if view.focus < len(view.scene.items) && view.scene.items[view.focus].shape == .Mesh {
		view.focus_offset = view.scene.camera.target - view.scene.items[view.focus].position
	}
	if !gl_renderer_init(&view.renderer) do return "the GL shaders did not compile"
	problem = scene_view_upload_meshes(view, meshes)
	if problem != "" do return fmt.tprintf("meshes: %s", problem)
	problem = scene_view_upload_textures(view, textures)
	if problem != "" do return fmt.tprintf("textures: %s", problem)
	return ""
}

scene_view_step :: proc(view: ^Scene_View, input: Scene_Input, delta_time: f32) {
	// A hidden tab delivers its whole span as one step; a walk that long would leave the scene.
	step_time := min(delta_time, SCENE_VIEW_STEP_LIMIT)
	switch view.scene.camera_mode {
	case .Fly:
		view.fly = scene_view_fly_step(view.fly, input, step_time)
	case .Orbit:
		view.orbit = scene_view_orbit_step(view.orbit, input, step_time)
		if input.focus_step != 0 do scene_view_focus_step(view, input.focus_step)
	}
	count := scene_configuration_count(view.scene)
	if input.cycle_configuration do view.configuration = (view.configuration + 1) % count
	if input.previous_configuration do view.configuration = (view.configuration + count - 1) % count
}

// The turn first, so the walk follows this frame's facing.
@(private = "file")
scene_view_fly_step :: proc(fly: Fly, input: Scene_Input, step_time: f32) -> Fly {
	result := fly
	if input.turn != {} do result = fly_turn(result, input.turn, 1)
	if input.move != {} do result = fly_walk(result, input.move, 1)
	if input.walk != {} do result = fly_walk(result, input.walk, SCENE_VIEW_FLY_SPEED * step_time)
	return result
}

// D and the stick right go round to the right, up rises, walk.z zooms in. The move is ignored.
@(private = "file")
scene_view_orbit_step :: proc(orbit: Orbit, input: Scene_Input, step_time: f32) -> Orbit {
	result := orbit_turn(orbit, input.turn, 1)
	result = orbit_turn(result, {-input.walk.x, input.walk.y}, SCENE_VIEW_ORBIT_TURN_RADIANS_PER_SECOND * step_time)
	zoom := input.zoom + input.walk.z * SCENE_VIEW_ZOOM_PER_SECOND * step_time
	return orbit_zoom(result, zoom, SCENE_VIEW_DISTANCE_MINIMUM, SCENE_VIEW_DISTANCE_MAXIMUM)
}

// The orbit keeps its yaw, pitch and distance and looks at the same point on the next model. A scene without mesh items keeps its target.
@(private = "file")
scene_view_focus_step :: proc(view: ^Scene_View, step: int) {
	next := scene_next_mesh_item(view.scene.items, view.focus, step)
	if next >= len(view.scene.items) || view.scene.items[next].shape != .Mesh do return
	view.focus = next
	view.orbit.target = view.scene.items[next].position + view.focus_offset
}

// The first mesh item after from in the direction of step's sign, wrapping, from itself when it is the only one, from when there is none.
scene_next_mesh_item :: proc(items: []Scene_Item, from, step: int) -> int {
	count := len(items)
	direction := step < 0 ? -1 : 1
	for offset in 1 ..= count {
		index := ((from + direction * offset) % count + count) % count
		if items[index].shape == .Mesh do return index
	}
	return from
}

// The mesh item whose position is nearest the point, 0 when there is none.
@(private = "file")
scene_nearest_mesh_item :: proc(items: []Scene_Item, point: [3]f32) -> int {
	nearest, nearest_distance := 0, max(f32)
	for item, index in items {
		distance := linalg.length2(item.position - point)
		if item.shape == .Mesh && distance < nearest_distance do nearest, nearest_distance = index, distance
	}
	return nearest
}

// The current configuration's name, "" for a scene that names none.
scene_view_configuration_name :: proc(view: ^Scene_View) -> string {
	if view.configuration >= len(view.scene.configurations) do return ""
	return view.scene.configurations[view.configuration]
}

scene_view_configuration_count :: proc(view: ^Scene_View) -> int {
	return scene_configuration_count(view.scene)
}

// Each item drawn at its position times its uniform scale, with its mesh of the current configuration or its current level.
scene_view_draw :: proc(view: ^Scene_View, width, height: i32) {
	draw_list_clear(&view.draw_list)
	view.draw_list.camera = scene_view_camera(view)
	scene_view_choose_levels(view, f32(height))
	view.draw_list.sun = view.scene.sun
	view.draw_list.exposure = view.scene.exposure
	view.draw_list.sky_colour = view.scene.sky_colour
	view.draw_list.ground_colour = view.scene.ground_colour
	for light in view.scene.lights {
		draw_list_add_light(&view.draw_list, light)
	}
	count := scene_configuration_count(view.scene)
	for item, index in view.scene.items {
		transform := linalg.matrix4_translate_f32(item.position) * linalg.matrix4_scale_f32({item.scale, item.scale, item.scale})
		levels := view.item_levels[index]
		if len(levels.mesh_ids) > 0 {
			draw_list_add(&view.draw_list, levels.mesh_ids[levels.current], item.material, transform, levels.half_extents)
			continue
		}
		entry := index * count + view.configuration
		draw_list_add(&view.draw_list, view.item_mesh_ids[entry], item.material, transform, view.item_half_extents[entry])
	}
	gl_renderer_draw(&view.renderer, view.draw_list, view.library, width, height)
}

// Each item with levels takes the level lod_choose gives the screen pixels of the sphere around its middle, none while the lod is frozen.
scene_view_choose_levels :: proc(view: ^Scene_View, canvas_height: f32) {
	if view.lod.freeze do return
	camera := scene_view_camera(view)
	for &levels, index in view.item_levels {
		if len(levels.triangle_counts) == 0 do continue
		item := view.scene.items[index]
		centre := item.position + {0, levels.half_extents.y * item.scale, 0}
		radius := linalg.length(levels.half_extents) * item.scale
		pixels := lod_screen_pixels(camera, canvas_height, centre, radius)
		levels.current = lod_choose(levels.current, levels.triangle_counts, pixels, view.lod.pixels_per_triangle, view.lod.hysteresis)
	}
}

scene_view_camera :: proc(view: ^Scene_View) -> Camera {
	if view.scene.camera_mode == .Orbit do return orbit_camera(view.orbit, SCENE_VIEW_VERTICAL_FOV, 0.1, 100)
	return fly_camera(view.fly, SCENE_VIEW_VERTICAL_FOV, 0.1, 100)
}

// The label's point in the canvas's units from its top left, not visible out of range.
scene_view_label_screen :: proc(view: ^Scene_View, index: int, canvas: [2]f32) -> (pixel: [2]f32, visible: bool) {
	if index < 0 || index >= len(view.scene.labels) do return {}, false
	aspect := canvas.x / max(canvas.y, 1e-3)
	return world_to_screen(scene_view_camera(view), aspect, canvas, view.scene.labels[index].position)
}

// Frees the GL objects, the parsed data and the draw list.
scene_view_destroy :: proc(view: ^Scene_View) {
	gl_renderer_destroy(&view.renderer)
	draw_list_destroy(&view.draw_list)
	delete(view.item_mesh_ids)
	delete(view.item_half_extents)
	for levels in view.item_levels {
		delete(levels.mesh_ids)
		delete(levels.triangle_counts)
	}
	delete(view.item_levels)
	scene_destroy(&view.scene)
	material_library_destroy(&view.library)
	view^ = {}
}

// A blob uploaded once, shared by every configuration and level that names its file.
@(private = "file")
Scene_View_Blob :: struct {
	mesh_id:        Mesh_Id,
	half_extents:   [3]f32,
	triangle_count: int,
}

// The half extents are kept from the parsed mesh, which is freed once uploaded. A blob file shared by several entries or levels is uploaded once and a primitive once per item, its first upload reused. An item with levels fills every configuration's entry with its finest level.
@(private = "file")
scene_view_upload_meshes :: proc(view: ^Scene_View, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	count := scene_configuration_count(view.scene)
	view.item_mesh_ids = make([]Mesh_Id, len(view.scene.items) * count)
	view.item_half_extents = make([][3]f32, len(view.scene.items) * count)
	view.item_levels = make([]Scene_Item_Levels, len(view.scene.items))
	blob_by_file := make(map[string]Scene_View_Blob, context.temp_allocator)
	defer delete(blob_by_file)
	for item, index in view.scene.items {
		if len(item.levels) > 0 {
			if problem = scene_view_upload_levels(view, index, &blob_by_file, meshes); problem != "" do return problem
		}
		for configuration in 0 ..< count {
			entry := index * count + configuration
			blob: Scene_View_Blob
			switch {
			case len(item.levels) > 0:
				blob = {view.item_levels[index].mesh_ids[0], view.item_levels[index].half_extents, 0}
			case item.shape == .Mesh:
				if blob, problem = scene_view_upload_blob(view, scene_item_file(item, configuration), &blob_by_file, meshes); problem != "" do return problem
			case configuration > 0:
				blob = {view.item_mesh_ids[index * count], view.item_half_extents[index * count], 0}
			case:
				mesh: Mesh_Data
				if mesh, problem = scene_item_mesh(item, configuration, meshes); problem != "" do return problem
				blob = {gl_renderer_upload_mesh(&view.renderer, mesh), scene_item_half_extents(item, mesh), 0}
				mesh_data_destroy(&mesh)
			}
			view.item_mesh_ids[entry] = blob.mesh_id
			view.item_half_extents[entry] = blob.half_extents
		}
	}
	return ""
}

@(private = "file")
scene_view_upload_levels :: proc(view: ^Scene_View, index: int, blob_by_file: ^map[string]Scene_View_Blob, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	level_files := view.scene.items[index].levels
	levels := &view.item_levels[index]
	levels.mesh_ids = make([]Mesh_Id, len(level_files))
	levels.triangle_counts = make([]int, len(level_files))
	for file_name, level in level_files {
		blob: Scene_View_Blob
		if blob, problem = scene_view_upload_blob(view, file_name, blob_by_file, meshes); problem != "" do return problem
		levels.mesh_ids[level] = blob.mesh_id
		levels.triangle_counts[level] = blob.triangle_count
	}
	if blob, found := blob_by_file[level_files[0]]; found do levels.half_extents = blob.half_extents
	return ""
}

// The blob of the file name, uploaded on its first use and recorded in blob_by_file.
@(private = "file")
scene_view_upload_blob :: proc(view: ^Scene_View, file_name: string, blob_by_file: ^map[string]Scene_View_Blob, meshes: []runtime.Load_Directory_File) -> (blob: Scene_View_Blob, problem: string) {
	if uploaded, found := blob_by_file[file_name]; found do return uploaded, ""
	mesh: Mesh_Data
	if mesh, problem = scene_mesh_file_parse(file_name, meshes); problem != "" do return {}, problem
	blob = {gl_renderer_upload_mesh(&view.renderer, mesh), mesh_half_extents(mesh), len(mesh.indices) / 3}
	mesh_data_destroy(&mesh)
	blob_by_file[file_name] = blob
	return blob, ""
}

// One set per material that names one; the decoded pixels live in the temp allocator until uploaded.
@(private = "file")
scene_view_upload_textures :: proc(view: ^Scene_View, textures: []runtime.Load_Directory_File) -> (problem: string) {
	for material, index in view.library.materials {
		if material.textures == "" do continue
		set: Texture_Set_Data
		set, problem = texture_set_from_files(textures, material.textures, context.temp_allocator)
		if problem != "" do return problem
		gl_renderer_upload_texture_set(&view.renderer, Material_Id(index), set)
	}
	return ""
}
