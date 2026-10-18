// The light demo: the scene of data/demos/light/scene.sjson, primitives in
// library materials under a sun and two lamps, drawn through the engine's
// WebGL2 renderer.
package light

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sys/wasm/js"
import engine "../../engine"
import gl "vendor:wasm/WebGL"

renderer: engine.Webgl_Renderer
library: engine.Material_Library
draw_list: engine.Draw_List
scene: engine.Scene
item_mesh_ids: []engine.Mesh_Id
canvas_width, canvas_height: i32
orbit: engine.Orbit

DRAG_RADIANS_PER_PIXEL :: f32(0.005)
WHEEL_ZOOM_STEP :: f32(1.1)
ORBIT_DISTANCE_MINIMUM :: f32(2)
ORBIT_DISTANCE_MAXIMUM :: f32(20)

// A pointer on the canvas: one drags the orbit, two pinch the distance.
Active_Pointer :: struct {
	pointer_id: int,
	client:     [2]f32,
}

active_pointers: [2]Active_Pointer
active_pointer_count: int

main :: proc() {
	gl.CreateCurrentContextById("canvas", {})
	resize_canvas()
	js.add_window_event_listener(.Resize, nil, on_resize)
	js.add_event_listener("canvas", .Pointer_Down, nil, on_pointer_down)
	js.add_event_listener("canvas", .Pointer_Move, nil, on_pointer_move)
	js.add_event_listener("canvas", .Pointer_Up, nil, on_pointer_up)
	js.add_event_listener("canvas", .Pointer_Cancel, nil, on_pointer_up)
	js.add_event_listener("canvas", .Wheel, nil, on_wheel)
	problem: string
	library, problem = engine.parse_material_library(#load("../../../data/materials/library.sjson"))
	if problem != "" {
		fmt.eprintln("material library:", problem)
		return
	}
	scene, problem = engine.parse_scene(#load("../../../data/demos/light/scene.sjson"), library)
	if problem != "" {
		fmt.eprintln("scene:", problem)
		return
	}
	orbit = scene.camera
	if !engine.webgl_renderer_init(&renderer) {
		fmt.eprintln("the WebGL2 shaders did not compile")
		return
	}
	item_mesh_ids = make([]engine.Mesh_Id, len(scene.items))
	for item, index in scene.items {
		item_mesh_ids[index] = upload_and_destroy(engine.scene_item_mesh(item))
	}
}

upload_and_destroy :: proc(mesh: engine.Mesh_Data) -> engine.Mesh_Id {
	mesh := mesh
	id := engine.webgl_renderer_upload_mesh(&renderer, mesh)
	engine.mesh_data_destroy(&mesh)
	return id
}

resize_canvas :: proc() {
	pixel_ratio := js.device_pixel_ratio()
	width := js.get_element_key_f64("canvas", "clientWidth") * pixel_ratio
	height := js.get_element_key_f64("canvas", "clientHeight") * pixel_ratio
	js.set_element_key_f64("canvas", "width", width)
	js.set_element_key_f64("canvas", "height", height)
	canvas_width = i32(width)
	canvas_height = i32(height)
}

on_resize :: proc(event: js.Event) {
	resize_canvas()
}

find_active_pointer :: proc(pointer_id: int) -> (slot: int, found: bool) {
	for index in 0 ..< active_pointer_count {
		if active_pointers[index].pointer_id == pointer_id do return index, true
	}
	return 0, false
}

add_active_pointer :: proc(pointer_id: int, client: [2]f32) {
	if slot, found := find_active_pointer(pointer_id); found {
		active_pointers[slot].client = client
		return
	}
	if active_pointer_count == len(active_pointers) do return
	active_pointers[active_pointer_count] = {pointer_id, client}
	active_pointer_count += 1
}

remove_active_pointer :: proc(slot: int) {
	active_pointer_count -= 1
	active_pointers[slot] = active_pointers[active_pointer_count]
}

pointer_client :: proc(event: js.Event) -> [2]f32 {
	return {f32(event.data.mouse.client.x), f32(event.data.mouse.client.y)}
}

pointer_spread :: proc() -> f32 {
	return linalg.length(active_pointers[1].client - active_pointers[0].client)
}

on_pointer_down :: proc(event: js.Event) {
	add_active_pointer(event.data.mouse.pointer.pointer_id, pointer_client(event))
}

on_pointer_move :: proc(event: js.Event) {
	slot, found := find_active_pointer(event.data.mouse.pointer.pointer_id)
	if !found do return
	if active_pointer_count == 1 {
		// The client delta, not the event's movement: odin.js stores the
		// browser's fractional movement as i64, and a value in (-1, 0) breaks.
		client := pointer_client(event)
		movement := client - active_pointers[slot].client
		active_pointers[slot].client = client
		orbit = engine.orbit_drag(orbit, movement, DRAG_RADIANS_PER_PIXEL)
		return
	}
	spread_before := pointer_spread()
	active_pointers[slot].client = pointer_client(event)
	spread_after := pointer_spread()
	if spread_before == 0 || spread_after == 0 do return
	orbit = engine.orbit_zoom(orbit, spread_before / spread_after, ORBIT_DISTANCE_MINIMUM, ORBIT_DISTANCE_MAXIMUM)
}

on_pointer_up :: proc(event: js.Event) {
	slot, found := find_active_pointer(event.data.mouse.pointer.pointer_id)
	if found do remove_active_pointer(slot)
}

on_wheel :: proc(event: js.Event) {
	delta := event.data.wheel.delta.y
	if delta == 0 do return
	factor := delta > 0 ? WHEEL_ZOOM_STEP : 1 / WHEEL_ZOOM_STEP
	orbit = engine.orbit_zoom(orbit, factor, ORBIT_DISTANCE_MINIMUM, ORBIT_DISTANCE_MAXIMUM)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.draw_list_clear(&draw_list)
	draw_list.camera = engine.orbit_camera(orbit, math.PI / 3, 0.1, 100)
	draw_list.sun = scene.sun
	draw_list.exposure = scene.exposure
	for light in scene.lights {
		engine.draw_list_add_light(&draw_list, light)
	}
	for item, index in scene.items {
		engine.draw_list_add(&draw_list, item_mesh_ids[index], item.material, linalg.matrix4_translate_f32(item.position))
	}
	engine.webgl_renderer_draw(&renderer, draw_list, library, canvas_width, canvas_height)
	return true
}
