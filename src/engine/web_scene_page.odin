#+build js wasm32
package engine

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

SCENE_PAGE_DRAG_RADIANS_PER_PIXEL :: f32(0.005)
SCENE_PAGE_DISTANCE_MAXIMUM :: f32(30) // Enough for the models page's row on a phone in portrait.
SCENE_PAGE_VERTICAL_FOV :: f32(math.PI / 3)
// Metres per second a held key or the stick walks the fly.
SCENE_PAGE_FLY_SPEED :: f32(5)
SCENE_PAGE_STEP_LIMIT :: f32(0.1)
SCENE_PAGE_STICK_DEAD_ZONE :: f32(0.15)
SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND :: f32(2)

// A pointer on the canvas: the mouse over it or a finger down, the primary one turning the fly.
Scene_Page_Pointer :: struct {
	pointer_id: int,
	client:     [2]f32,
}

// A scene drawn on a canvas, seen through the fly camera: the mouse or a finger looks, the keys or a gamepad walk.
Scene_Page :: struct {
	canvas_id:                   string,
	renderer:                    Webgl_Renderer,
	library:                     Material_Library,
	scene:                       Scene,
	item_mesh_ids:               []Mesh_Id,
	item_half_extents:           [][3]f32,
	draw_list:                   Draw_List,
	fly:                         Fly,
	canvas_width, canvas_height: i32,
	aspect, pixel_ratio:         f32,
	active_pointers:             [2]Scene_Page_Pointer,
	active_pointer_count:        int,
	keys_held:                   bit_set[Scene_Page_Key],
	gamepad_index:               int,
	ready:                       bool,
}

// The page the label exports read, for the page's labels.js.
@(private = "file")
registered_page: ^Scene_Page

scene_page_register :: proc(page: ^Scene_Page) {
	registered_page = page
}

scene_page_init :: proc(page: ^Scene_Page, canvas_id: string, library_data, scene_data: []byte, textures, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	page.canvas_id = canvas_id
	page.gamepad_index = -1
	scene_page_register(page)
	gl.CreateCurrentContextById(canvas_id, {})
	scene_page_resize(page)
	scene_page_listen(page)
	page.library, problem = parse_material_library(library_data)
	if problem != "" do return fmt.tprintf("material library: %s", problem)
	page.scene, problem = parse_scene(scene_data, page.library)
	if problem != "" do return fmt.tprintf("scene: %s", problem)
	page.fly = fly_from_orbit(orbit_fit_width(page.scene.camera, page.scene.fit_width, SCENE_PAGE_VERTICAL_FOV, page.aspect, SCENE_PAGE_DISTANCE_MAXIMUM))
	if !webgl_renderer_init(&page.renderer) do return "the WebGL2 shaders did not compile"
	problem = scene_page_upload_meshes(page, meshes)
	if problem != "" do return fmt.tprintf("meshes: %s", problem)
	problem = scene_page_upload_textures(page, textures)
	if problem != "" do return fmt.tprintf("textures: %s", problem)
	page.ready = true
	return ""
}

// Draws nothing until the init has run through.
scene_page_step :: proc(page: ^Scene_Page, delta_time: f32) {
	if !page.ready do return
	// A hidden tab delivers its whole span as one step; a walk that long would leave the scene.
	step_time := min(delta_time, SCENE_PAGE_STEP_LIMIT)
	scene_page_walk(page, step_time)
	scene_page_gamepad(page, step_time)
	draw_list_clear(&page.draw_list)
	page.draw_list.camera = scene_page_camera(page)
	page.draw_list.sun = page.scene.sun
	page.draw_list.exposure = page.scene.exposure
	page.draw_list.sky_colour = page.scene.sky_colour
	page.draw_list.ground_colour = page.scene.ground_colour
	for light in page.scene.lights {
		draw_list_add_light(&page.draw_list, light)
	}
	for item, index in page.scene.items {
		transform := linalg.matrix4_translate_f32(item.position) * linalg.matrix4_scale_f32({item.scale, item.scale, item.scale})
		draw_list_add(&page.draw_list, page.item_mesh_ids[index], item.material, transform, page.item_half_extents[index])
	}
	webgl_renderer_draw(&page.renderer, page.draw_list, page.library, page.canvas_width, page.canvas_height)
}

@(private = "file")
scene_page_camera :: proc(page: ^Scene_Page) -> Camera {
	return fly_camera(page.fly, SCENE_PAGE_VERTICAL_FOV, 0.1, 100)
}

// The registered page's label at index, found false out of range.
@(private = "file")
scene_page_label :: proc "contextless" (index: i32) -> (label: Scene_Label, found: bool) {
	if registered_page == nil || index < 0 || int(index) >= len(registered_page.scene.labels) do return {}, false
	return registered_page.scene.labels[index], true
}

// The label's point in CSS pixels from the canvas's top left.
@(private = "file")
scene_page_label_screen :: proc "contextless" (index: i32) -> (pixel: [2]f32, visible: bool) {
	label, found := scene_page_label(index)
	if !found do return {}, false
	// The camera procedures take a context; the default one allocates nothing here.
	context = runtime.default_context()
	page := registered_page
	canvas := [2]f32{f32(page.canvas_width), f32(page.canvas_height)} / max(page.pixel_ratio, 1e-3)
	return world_to_screen(scene_page_camera(page), page.aspect, canvas, label.position)
}

@(export)
label_count :: proc "contextless" () -> i32 {
	if registered_page == nil do return 0
	return i32(len(registered_page.scene.labels))
}

@(export)
label_text_pointer :: proc "contextless" (index: i32) -> rawptr {
	label, _ := scene_page_label(index)
	return raw_data(label.text)
}

@(export)
label_text_length :: proc "contextless" (index: i32) -> i32 {
	label, _ := scene_page_label(index)
	return i32(len(label.text))
}

@(export)
label_screen_x :: proc "contextless" (index: i32) -> f32 {
	pixel, _ := scene_page_label_screen(index)
	return pixel.x
}

@(export)
label_screen_y :: proc "contextless" (index: i32) -> f32 {
	pixel, _ := scene_page_label_screen(index)
	return pixel.y
}

@(export)
label_visible :: proc "contextless" (index: i32) -> bool {
	_, visible := scene_page_label_screen(index)
	return visible
}

// Held keys walk the fly; opposite keys cancel.
@(private = "file")
scene_page_walk :: proc(page: ^Scene_Page, delta_time: f32) {
	keys := page.keys_held
	input := [3]f32 {
		f32(int(.Right in keys) - int(.Left in keys)),
		f32(int(.Up in keys) - int(.Down in keys)),
		f32(int(.Forward in keys) - int(.Back in keys)),
	}
	if input == {} do return
	page.fly = fly_walk(page.fly, input, SCENE_PAGE_FLY_SPEED * delta_time)
}

// The standard mapping: the left stick walks, the right stick turns, the d-pad moves up and down.
@(private = "file")
scene_page_gamepad :: proc(page: ^Scene_Page, delta_time: f32) {
	state: js.Gamepad_State
	if page.gamepad_index < 0 || !js.get_gamepad_state(page.gamepad_index, &state) || !state.connected do return
	left := [2]f32{stick_dead_zone(f32(state.axes[0]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[1]), SCENE_PAGE_STICK_DEAD_ZONE)}
	right := [2]f32{stick_dead_zone(f32(state.axes[2]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[3]), SCENE_PAGE_STICK_DEAD_ZONE)}
	vertical := f32(int(state.buttons[12].pressed) - int(state.buttons[13].pressed))
	walk_input := [3]f32{left.x, vertical, -left.y}
	if walk_input != {} {
		page.fly = fly_walk(page.fly, walk_input, SCENE_PAGE_FLY_SPEED * delta_time)
	}
	if right != {} {
		page.fly = fly_turn(page.fly, right * SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND * delta_time, 1)
	}
}

@(private = "file")
scene_page_listen :: proc(page: ^Scene_Page) {
	js.add_window_event_listener(.Resize, page, on_scene_page_resize)
	js.add_window_event_listener(.Key_Down, page, on_scene_page_key_down)
	js.add_window_event_listener(.Key_Up, page, on_scene_page_key_up)
	js.add_window_event_listener(.Blur, page, on_scene_page_blur)
	js.add_window_event_listener(.Gamepad_Connected, page, on_scene_page_gamepad_connected)
	js.add_window_event_listener(.Gamepad_Disconnected, page, on_scene_page_gamepad_disconnected)
	js.add_event_listener(page.canvas_id, .Pointer_Down, page, on_scene_page_pointer_down)
	js.add_event_listener(page.canvas_id, .Pointer_Move, page, on_scene_page_pointer_move)
	js.add_event_listener(page.canvas_id, .Pointer_Up, page, on_scene_page_pointer_up)
	js.add_event_listener(page.canvas_id, .Pointer_Cancel, page, on_scene_page_pointer_up)
	js.add_event_listener(page.canvas_id, .Pointer_Leave, page, on_scene_page_pointer_up)
}

// The half extents are kept from the parsed mesh, which is freed once uploaded.
@(private = "file")
scene_page_upload_meshes :: proc(page: ^Scene_Page, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	page.item_mesh_ids = make([]Mesh_Id, len(page.scene.items))
	page.item_half_extents = make([][3]f32, len(page.scene.items))
	for item, index in page.scene.items {
		mesh: Mesh_Data
		if mesh, problem = scene_item_mesh(item, meshes); problem != "" do return problem
		page.item_mesh_ids[index] = webgl_renderer_upload_mesh(&page.renderer, mesh)
		page.item_half_extents[index] = scene_item_half_extents(item, mesh)
		mesh_data_destroy(&mesh)
	}
	return ""
}

// One set per material that names one; the decoded pixels live in the temp allocator until uploaded.
@(private = "file")
scene_page_upload_textures :: proc(page: ^Scene_Page, textures: []runtime.Load_Directory_File) -> (problem: string) {
	for material, index in page.library.materials {
		if material.textures == "" do continue
		set: Texture_Set_Data
		set, problem = texture_set_from_files(textures, material.textures, context.temp_allocator)
		if problem != "" do return problem
		webgl_renderer_upload_texture_set(&page.renderer, Material_Id(index), set)
	}
	return ""
}

@(private = "file")
scene_page_resize :: proc(page: ^Scene_Page) {
	pixel_ratio := js.device_pixel_ratio()
	client_height := js.get_element_key_f64(page.canvas_id, "clientHeight")
	width := js.get_element_key_f64(page.canvas_id, "clientWidth") * pixel_ratio
	height := client_height * pixel_ratio
	js.set_element_key_f64(page.canvas_id, "width", width)
	js.set_element_key_f64(page.canvas_id, "height", height)
	page.canvas_width = i32(width)
	page.canvas_height = i32(height)
	page.pixel_ratio = f32(pixel_ratio)
	// From the whole pixels, as the renderer's viewport, so a plaque's point is the drawn one.
	page.aspect = f32(page.canvas_width) / f32(max(page.canvas_height, 1))
}

@(private = "file")
on_scene_page_resize :: proc(event: js.Event) {
	scene_page_resize((^Scene_Page)(event.user_data))
}

@(private = "file")
on_scene_page_key_down :: proc(event: js.Event) {
	if event.data.key.repeat do return
	key, known := scene_page_key_from_code(event.data.key.code)
	if !known do return
	page := (^Scene_Page)(event.user_data)
	page.keys_held += {key}
}

// The browser sends no key up for a key released while another window has focus.
@(private = "file")
on_scene_page_blur :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	page.keys_held = {}
}

@(private = "file")
on_scene_page_key_up :: proc(event: js.Event) {
	key, known := scene_page_key_from_code(event.data.key.code)
	if !known do return
	page := (^Scene_Page)(event.user_data)
	page.keys_held -= {key}
}

@(private = "file")
on_scene_page_gamepad_connected :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	page.gamepad_index = event.data.gamepad.index
}

@(private = "file")
on_scene_page_gamepad_disconnected :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	if page.gamepad_index == event.data.gamepad.index do page.gamepad_index = -1
}

@(private = "file")
scene_page_find_pointer :: proc(page: ^Scene_Page, pointer_id: int) -> (slot: int, found: bool) {
	for index in 0 ..< page.active_pointer_count {
		if page.active_pointers[index].pointer_id == pointer_id do return index, true
	}
	return 0, false
}

@(private = "file")
scene_page_add_pointer :: proc(page: ^Scene_Page, pointer_id: int, client: [2]f32) {
	if slot, found := scene_page_find_pointer(page, pointer_id); found {
		page.active_pointers[slot].client = client
		return
	}
	if page.active_pointer_count == len(page.active_pointers) do return
	page.active_pointers[page.active_pointer_count] = {pointer_id, client}
	page.active_pointer_count += 1
}

@(private = "file")
scene_page_remove_pointer :: proc(page: ^Scene_Page, slot: int) {
	page.active_pointer_count -= 1
	page.active_pointers[slot] = page.active_pointers[page.active_pointer_count]
}

@(private = "file")
scene_page_pointer_client :: proc(event: js.Event) -> [2]f32 {
	return {f32(event.data.mouse.client.x), f32(event.data.mouse.client.y)}
}

@(private = "file")
on_scene_page_pointer_down :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	scene_page_add_pointer(page, event.data.mouse.pointer.pointer_id, scene_page_pointer_client(event))
}

// The primary pointer turns the fly; a mouse joins on its first move over the canvas, a finger on its down.
@(private = "file")
on_scene_page_pointer_move :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	pointer := event.data.mouse.pointer
	if !pointer.is_primary do return
	client := scene_page_pointer_client(event)
	slot, found := scene_page_find_pointer(page, pointer.pointer_id)
	if !found {
		if pointer.pointer_type == .Mouse do scene_page_add_pointer(page, pointer.pointer_id, client)
		return
	}
	// The client delta, not the event's movement: odin.js stores the
	// browser's fractional movement as i64, and a value in (-1, 0) breaks.
	movement := client - page.active_pointers[slot].client
	page.active_pointers[slot].client = client
	page.fly = fly_turn(page.fly, movement, SCENE_PAGE_DRAG_RADIANS_PER_PIXEL)
}

@(private = "file")
on_scene_page_pointer_up :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	slot, found := scene_page_find_pointer(page, event.data.mouse.pointer.pointer_id)
	if found do scene_page_remove_pointer(page, slot)
}
