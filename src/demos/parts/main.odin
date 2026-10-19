// The parts demo: the scene of data/demos/parts/scene.sjson, the smelter
// split into its brief's parts by tools/models/parts.py, each part in its
// brief material, drawn through the engine's WebGL2 renderer.
package parts

import "core:fmt"
import engine "../../engine"

page: engine.Scene_Page

main :: proc() {
	problem := engine.scene_page_init(&page, "canvas", #load("../../../data/materials/library.sjson"), #load("../../../data/demos/parts/scene.sjson"), #load_directory("../../../data/materials/textures"), #load_directory("../../../data/demos/parts/meshes"))
	if problem != "" do fmt.eprintln(problem)
	// The decoded textures and any problem live in the temp arena until here.
	free_all(context.temp_allocator)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.scene_page_step(&page, f32(delta_time))
	return true
}
