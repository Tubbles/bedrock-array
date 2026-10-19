// The decimation demo: the scene of data/demos/decimation/scene.sjson, the
// full smelter model and Blender decimations of its Poisson closing in a row,
// a label over each, drawn through the engine's WebGL2 renderer.
package decimation

import "core:fmt"
import engine "../../engine"

page: engine.Scene_Page

main :: proc() {
	problem := engine.scene_page_init(&page, "canvas", #load("../../../data/materials/library.sjson"), #load("../../../data/demos/decimation/scene.sjson"), #load_directory("../../../data/materials/textures"), #load_directory("../../../data/demos/decimation/meshes"))
	if problem != "" do fmt.eprintln(problem)
	// The decoded textures and any problem live in the temp arena until here.
	free_all(context.temp_allocator)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.scene_page_step(&page, f32(delta_time))
	return true
}
