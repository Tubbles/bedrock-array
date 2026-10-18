// The light demo: three primitives on a slab in library materials, lit by
// one directional light, drawn through the engine's WebGL2 renderer.
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
box_mesh_id, cylinder_mesh_id, slab_mesh_id: engine.Mesh_Id
painted_steel_id, copper_id, concrete_id: engine.Material_Id
canvas_width, canvas_height: i32

main :: proc() {
	gl.CreateCurrentContextById("canvas", {})
	resize_canvas()
	js.add_window_event_listener(.Resize, nil, on_resize)
	problem: string
	library, problem = engine.parse_material_library(#load("../../../data/materials/library.sjson"))
	if problem != "" {
		fmt.eprintln("material library:", problem)
		return
	}
	painted_steel_id, _ = engine.material_id_by_name(library, "painted_steel")
	copper_id, _ = engine.material_id_by_name(library, "copper")
	concrete_id, _ = engine.material_id_by_name(library, "concrete")
	if !engine.webgl_renderer_init(&renderer) {
		fmt.eprintln("the WebGL2 shaders did not compile")
		return
	}
	box_mesh_id = upload_and_destroy(engine.box_mesh({1, 1, 1}))
	cylinder_mesh_id = upload_and_destroy(engine.cylinder_mesh(0.5, 1, 24))
	slab_mesh_id = upload_and_destroy(engine.box_mesh({6, 0.1, 6}))
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

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.draw_list_clear(&draw_list)
	draw_list.camera = engine.orbit_camera({target = {0, 0.5, 0}, yaw = 0.6, pitch = 0.5, distance = 5}, math.PI / 3, 0.1, 100)
	draw_list.sun = {direction = linalg.normalize([3]f32{0.4, -1, -0.3}), colour = {1, 0.96, 0.9}, intensity = 1}
	engine.draw_list_add(&draw_list, box_mesh_id, painted_steel_id, linalg.matrix4_translate_f32({0, 0.5, 0}))
	engine.draw_list_add(&draw_list, cylinder_mesh_id, copper_id, linalg.matrix4_translate_f32({1.5, 0.5, 0}))
	engine.draw_list_add(&draw_list, slab_mesh_id, concrete_id, linalg.matrix4_translate_f32({0, -0.05, 0}))
	engine.webgl_renderer_draw(&renderer, draw_list, library, canvas_width, canvas_height)
	return true
}
