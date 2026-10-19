#+build js wasm32
package engine

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

SCENE_PAGE_DRAG_RADIANS_PER_PIXEL :: f32(0.005)
SCENE_PAGE_WHEEL_ZOOM_STEP :: f32(1.1)
SCENE_PAGE_DISTANCE_MINIMUM :: f32(2)
SCENE_PAGE_DISTANCE_MAXIMUM :: f32(20)
// Orbit distances per second a held key walks the target.
SCENE_PAGE_WALK_SPEED :: f32(0.6)
SCENE_PAGE_STEP_LIMIT :: f32(0.1)
SCENE_PAGE_STICK_DEAD_ZONE :: f32(0.15)
SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND :: f32(2)
SCENE_PAGE_TRIGGER_ZOOM_PER_SECOND :: f32(0.8)

// A pointer on the canvas: one drags the orbit, two pinch the distance.
Scene_Page_Pointer :: struct {
	pointer_id: int,
	client:     [2]f32,
}

// A walk direction held on the keyboard.
Scene_Page_Key :: enum {
	Forward,
	Back,
	Left,
	Right,
	Up,
	Down,
}

// A scene drawn on a canvas, orbited by drag, pinch and wheel.
Scene_Page :: struct {
	canvas_id:                   string,
	renderer:                    Webgl_Renderer,
	library:                     Material_Library,
	scene:                       Scene,
	item_mesh_ids:               []Mesh_Id,
	item_half_extents:           [][3]f32,
	draw_list:                   Draw_List,
	orbit:                       Orbit,
	canvas_width, canvas_height: i32,
	client_height:               f32,
	active_pointers:             [2]Scene_Page_Pointer,
	active_pointer_count:        int,
	keys_held:                   bit_set[Scene_Page_Key],
	gamepad_index:               int,
	ready:                       bool,
}

scene_page_init :: proc(page: ^Scene_Page, canvas_id: string, library_data, scene_data: []byte, textures, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	page.canvas_id = canvas_id
	page.gamepad_index = -1
	gl.CreateCurrentContextById(canvas_id, {})
	scene_page_resize(page)
	scene_page_listen(page)
	page.library, problem = parse_material_library(library_data)
	if problem != "" do return fmt.tprintf("material library: %s", problem)
	page.scene, problem = parse_scene(scene_data, page.library)
	if problem != "" do return fmt.tprintf("scene: %s", problem)
	page.orbit = page.scene.camera
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
	page.draw_list.camera = orbit_camera(page.orbit, math.PI / 3, 0.1, 100)
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

// Held keys walk the target at a pace proportional to the orbit distance; opposite keys cancel.
@(private = "file")
scene_page_walk :: proc(page: ^Scene_Page, delta_time: f32) {
	keys := page.keys_held
	input := [3]f32 {
		f32(int(.Right in keys) - int(.Left in keys)),
		f32(int(.Up in keys) - int(.Down in keys)),
		f32(int(.Forward in keys) - int(.Back in keys)),
	}
	if input == {} do return
	page.orbit = orbit_walk(page.orbit, input, page.orbit.distance * SCENE_PAGE_WALK_SPEED * delta_time)
}

// The standard mapping: the left stick walks, the right stick turns, the triggers zoom, the d-pad moves up and down.
@(private = "file")
scene_page_gamepad :: proc(page: ^Scene_Page, delta_time: f32) {
	state: js.Gamepad_State
	if page.gamepad_index < 0 || !js.get_gamepad_state(page.gamepad_index, &state) || !state.connected do return
	left := [2]f32{stick_dead_zone(f32(state.axes[0]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[1]), SCENE_PAGE_STICK_DEAD_ZONE)}
	right := [2]f32{stick_dead_zone(f32(state.axes[2]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[3]), SCENE_PAGE_STICK_DEAD_ZONE)}
	vertical := f32(int(state.buttons[12].pressed) - int(state.buttons[13].pressed))
	walk_input := [3]f32{left.x, vertical, -left.y}
	if walk_input != {} {
		page.orbit = orbit_walk(page.orbit, walk_input, page.orbit.distance * SCENE_PAGE_WALK_SPEED * delta_time)
	}
	if right != {} {
		page.orbit = orbit_drag(page.orbit, right * SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND * delta_time, 1)
	}
	trigger := f32(state.buttons[7].value) - f32(state.buttons[6].value)
	if trigger != 0 {
		page.orbit = orbit_zoom(page.orbit, 1 - trigger * SCENE_PAGE_TRIGGER_ZOOM_PER_SECOND * delta_time, SCENE_PAGE_DISTANCE_MINIMUM, SCENE_PAGE_DISTANCE_MAXIMUM)
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
	js.add_event_listener(page.canvas_id, .Wheel, page, on_scene_page_wheel)
	js.add_event_listener(page.canvas_id, .Context_Menu, page, on_scene_page_context_menu)
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
	page.client_height = f32(client_height)
	width := js.get_element_key_f64(page.canvas_id, "clientWidth") * pixel_ratio
	height := client_height * pixel_ratio
	js.set_element_key_f64(page.canvas_id, "width", width)
	js.set_element_key_f64(page.canvas_id, "height", height)
	page.canvas_width = i32(width)
	page.canvas_height = i32(height)
}

@(private = "file")
on_scene_page_resize :: proc(event: js.Event) {
	scene_page_resize((^Scene_Page)(event.user_data))
}

@(private = "file")
scene_page_key_from_code :: proc(code: string) -> (Scene_Page_Key, bool) {
	switch code {
	case "KeyW", "ArrowUp":
		return .Forward, true
	case "KeyS", "ArrowDown":
		return .Back, true
	case "KeyA", "ArrowLeft":
		return .Left, true
	case "KeyD", "ArrowRight":
		return .Right, true
	case "KeyE":
		return .Up, true
	case "KeyQ":
		return .Down, true
	}
	return .Forward, false
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
scene_page_pointer_spread :: proc(page: ^Scene_Page) -> f32 {
	return linalg.length(page.active_pointers[1].client - page.active_pointers[0].client)
}

@(private = "file")
scene_page_pointer_midpoint :: proc(page: ^Scene_Page) -> [2]f32 {
	return (page.active_pointers[0].client + page.active_pointers[1].client) / 2
}

// The orbit panned by a drag in CSS pixels, a pixel moving the target a pixel at its depth.
@(private = "file")
scene_page_pan :: proc(page: ^Scene_Page, delta_pixels: [2]f32) -> Orbit {
	return orbit_pan(page.orbit, delta_pixels, orbit_metres_per_pixel(page.orbit, math.PI / 3, max(page.client_height, 1)))
}

@(private = "file")
on_scene_page_pointer_down :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	scene_page_add_pointer(page, event.data.mouse.pointer.pointer_id, scene_page_pointer_client(event))
}

@(private = "file")
on_scene_page_pointer_move :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	slot, found := scene_page_find_pointer(page, event.data.mouse.pointer.pointer_id)
	if !found do return
	if page.active_pointer_count == 1 {
		// The client delta, not the event's movement: odin.js stores the
		// browser's fractional movement as i64, and a value in (-1, 0) breaks.
		client := scene_page_pointer_client(event)
		movement := client - page.active_pointers[slot].client
		page.active_pointers[slot].client = client
		if 1 in event.data.mouse.buttons {
			page.orbit = scene_page_pan(page, movement)
			return
		}
		page.orbit = orbit_drag(page.orbit, movement, SCENE_PAGE_DRAG_RADIANS_PER_PIXEL)
		return
	}
	spread_before := scene_page_pointer_spread(page)
	midpoint_before := scene_page_pointer_midpoint(page)
	page.active_pointers[slot].client = scene_page_pointer_client(event)
	spread_after := scene_page_pointer_spread(page)
	page.orbit = scene_page_pan(page, scene_page_pointer_midpoint(page) - midpoint_before)
	if spread_before == 0 || spread_after == 0 do return
	page.orbit = orbit_zoom(page.orbit, spread_before / spread_after, SCENE_PAGE_DISTANCE_MINIMUM, SCENE_PAGE_DISTANCE_MAXIMUM)
}

@(private = "file")
on_scene_page_pointer_up :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	slot, found := scene_page_find_pointer(page, event.data.mouse.pointer.pointer_id)
	if found do scene_page_remove_pointer(page, slot)
}

@(private = "file")
on_scene_page_wheel :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	delta := event.data.wheel.delta.y
	if delta == 0 do return
	factor := delta > 0 ? SCENE_PAGE_WHEEL_ZOOM_STEP : 1 / SCENE_PAGE_WHEEL_ZOOM_STEP
	page.orbit = orbit_zoom(page.orbit, factor, SCENE_PAGE_DISTANCE_MINIMUM, SCENE_PAGE_DISTANCE_MAXIMUM)
}

// The right button pans, so the browser's menu stays shut over the canvas.
@(private = "file")
on_scene_page_context_menu :: proc(event: js.Event) {
	js.event_prevent_default()
}
