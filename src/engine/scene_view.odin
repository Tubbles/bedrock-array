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

// One frame's input: walk per axis (right, up, forward), each from minus one to one, turn in radians (yaw, pitch), already scaled by the caller, and cycle_configuration the edge of the press the caller detects.
Scene_Input :: struct {
	walk:                [3]f32,
	turn:                [2]f32,
	// Metres in the fly's frame (right, up, forward), applied as given with no speed or frame time, for a gesture that already measured its distance.
	move:                [3]f32,
	cycle_configuration: bool,
}

// A scene drawn from its data through the fly camera, with no window or canvas of its own. The item arrays hold one entry per item and configuration, at item_index * count + configuration.
Scene_View :: struct {
	library:           Material_Library,
	scene:             Scene,
	renderer:          Gl_Renderer,
	item_mesh_ids:     []Mesh_Id,
	item_half_extents: [][3]f32,
	draw_list:         Draw_List,
	fly:               Fly,
	configuration:     int,
}

// Needs a current GL context; the aspect fits the start view.
scene_view_init :: proc(view: ^Scene_View, library_data, scene_data: []byte, textures, meshes: []runtime.Load_Directory_File, aspect: f32) -> (problem: string) {
	view.library, problem = parse_material_library(library_data)
	if problem != "" do return fmt.tprintf("material library: %s", problem)
	view.scene, problem = parse_scene(scene_data, view.library)
	if problem != "" do return fmt.tprintf("scene: %s", problem)
	view.fly = fly_from_orbit(orbit_fit_width(view.scene.camera, view.scene.fit_width, SCENE_VIEW_VERTICAL_FOV, aspect, SCENE_VIEW_DISTANCE_MAXIMUM))
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
	// The turn first, so the walk follows this frame's facing.
	if input.turn != {} do view.fly = fly_turn(view.fly, input.turn, 1)
	if input.move != {} do view.fly = fly_walk(view.fly, input.move, 1)
	if input.walk != {} do view.fly = fly_walk(view.fly, input.walk, SCENE_VIEW_FLY_SPEED * step_time)
	if input.cycle_configuration do view.configuration = (view.configuration + 1) % scene_configuration_count(view.scene)
}

// The current configuration's name, "" for a scene that names none.
scene_view_configuration_name :: proc(view: ^Scene_View) -> string {
	if view.configuration >= len(view.scene.configurations) do return ""
	return view.scene.configurations[view.configuration]
}

scene_view_configuration_count :: proc(view: ^Scene_View) -> int {
	return scene_configuration_count(view.scene)
}

// Each item drawn at its position times its uniform scale, with its mesh of the current configuration.
scene_view_draw :: proc(view: ^Scene_View, width, height: i32) {
	draw_list_clear(&view.draw_list)
	view.draw_list.camera = scene_view_camera(view)
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
		entry := index * count + view.configuration
		draw_list_add(&view.draw_list, view.item_mesh_ids[entry], item.material, transform, view.item_half_extents[entry])
	}
	gl_renderer_draw(&view.renderer, view.draw_list, view.library, width, height)
}

scene_view_camera :: proc(view: ^Scene_View) -> Camera {
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
	scene_destroy(&view.scene)
	material_library_destroy(&view.library)
	view^ = {}
}

// The half extents are kept from the parsed mesh, which is freed once uploaded. A blob file shared by several entries is uploaded once and a primitive once per item, the first entry's mesh and half extents reused.
@(private = "file")
scene_view_upload_meshes :: proc(view: ^Scene_View, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	count := scene_configuration_count(view.scene)
	view.item_mesh_ids = make([]Mesh_Id, len(view.scene.items) * count)
	view.item_half_extents = make([][3]f32, len(view.scene.items) * count)
	uploaded_entry_by_file := make(map[string]int, context.temp_allocator)
	defer delete(uploaded_entry_by_file)
	for item, index in view.scene.items {
		for configuration in 0 ..< count {
			entry := index * count + configuration
			uploaded, found := index * count, configuration > 0
			if item.shape == .Mesh {
				uploaded, found = uploaded_entry_by_file[scene_item_file(item, configuration)]
				if !found do uploaded_entry_by_file[scene_item_file(item, configuration)] = entry
			}
			if found {
				view.item_mesh_ids[entry] = view.item_mesh_ids[uploaded]
				view.item_half_extents[entry] = view.item_half_extents[uploaded]
				continue
			}
			mesh: Mesh_Data
			if mesh, problem = scene_item_mesh(item, configuration, meshes); problem != "" do return problem
			view.item_mesh_ids[entry] = gl_renderer_upload_mesh(&view.renderer, mesh)
			view.item_half_extents[entry] = scene_item_half_extents(item, mesh)
			mesh_data_destroy(&mesh)
		}
	}
	return ""
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
