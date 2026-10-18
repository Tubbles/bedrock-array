#+build js wasm32
package engine

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

SCENE_PAGE_DRAG_RADIANS_PER_PIXEL :: f32(0.005)
SCENE_PAGE_WHEEL_ZOOM_STEP :: f32(1.1)
SCENE_PAGE_DISTANCE_MINIMUM :: f32(2)
SCENE_PAGE_DISTANCE_MAXIMUM :: f32(20)

// A pointer on the canvas: one drags the orbit, two pinch the distance.
Scene_Page_Pointer :: struct {
	pointer_id: int,
	client:     [2]f32,
}

// A scene drawn on a canvas, orbited by drag, pinch and wheel.
Scene_Page :: struct {
	canvas_id:                   string,
	renderer:                    Webgl_Renderer,
	library:                     Material_Library,
	scene:                       Scene,
	item_mesh_ids:               []Mesh_Id,
	draw_list:                   Draw_List,
	orbit:                       Orbit,
	canvas_width, canvas_height: i32,
	active_pointers:             [2]Scene_Page_Pointer,
	active_pointer_count:        int,
	ready:                       bool,
}

scene_page_init :: proc(page: ^Scene_Page, canvas_id: string, library_data, scene_data: []byte) -> (problem: string) {
	page.canvas_id = canvas_id
	gl.CreateCurrentContextById(canvas_id, {})
	scene_page_resize(page)
	scene_page_listen(page)
	page.library, problem = parse_material_library(library_data)
	if problem != "" do return fmt.tprintf("material library: %s", problem)
	page.scene, problem = parse_scene(scene_data, page.library)
	if problem != "" do return fmt.tprintf("scene: %s", problem)
	page.orbit = page.scene.camera
	if !webgl_renderer_init(&page.renderer) do return "the WebGL2 shaders did not compile"
	scene_page_upload_meshes(page)
	page.ready = true
	return ""
}

// Draws nothing until the init has run through.
scene_page_step :: proc(page: ^Scene_Page) {
	if !page.ready do return
	draw_list_clear(&page.draw_list)
	page.draw_list.camera = orbit_camera(page.orbit, math.PI / 3, 0.1, 100)
	page.draw_list.sun = page.scene.sun
	page.draw_list.exposure = page.scene.exposure
	page.draw_list.ambient = page.scene.ambient
	for light in page.scene.lights {
		draw_list_add_light(&page.draw_list, light)
	}
	for item, index in page.scene.items {
		draw_list_add(&page.draw_list, page.item_mesh_ids[index], item.material, linalg.matrix4_translate_f32(item.position))
	}
	webgl_renderer_draw(&page.renderer, page.draw_list, page.library, page.canvas_width, page.canvas_height)
}

@(private = "file")
scene_page_listen :: proc(page: ^Scene_Page) {
	js.add_window_event_listener(.Resize, page, on_scene_page_resize)
	js.add_event_listener(page.canvas_id, .Pointer_Down, page, on_scene_page_pointer_down)
	js.add_event_listener(page.canvas_id, .Pointer_Move, page, on_scene_page_pointer_move)
	js.add_event_listener(page.canvas_id, .Pointer_Up, page, on_scene_page_pointer_up)
	js.add_event_listener(page.canvas_id, .Pointer_Cancel, page, on_scene_page_pointer_up)
	js.add_event_listener(page.canvas_id, .Wheel, page, on_scene_page_wheel)
}

@(private = "file")
scene_page_upload_meshes :: proc(page: ^Scene_Page) {
	page.item_mesh_ids = make([]Mesh_Id, len(page.scene.items))
	for item, index in page.scene.items {
		mesh := scene_item_mesh(item)
		page.item_mesh_ids[index] = webgl_renderer_upload_mesh(&page.renderer, mesh)
		mesh_data_destroy(&mesh)
	}
}

@(private = "file")
scene_page_resize :: proc(page: ^Scene_Page) {
	pixel_ratio := js.device_pixel_ratio()
	width := js.get_element_key_f64(page.canvas_id, "clientWidth") * pixel_ratio
	height := js.get_element_key_f64(page.canvas_id, "clientHeight") * pixel_ratio
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
		page.orbit = orbit_drag(page.orbit, movement, SCENE_PAGE_DRAG_RADIANS_PER_PIXEL)
		return
	}
	spread_before := scene_page_pointer_spread(page)
	page.active_pointers[slot].client = scene_page_pointer_client(event)
	spread_after := scene_page_pointer_spread(page)
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
