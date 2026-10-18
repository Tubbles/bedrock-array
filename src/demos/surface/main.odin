// The surface demo: the scene of data/demos/surface/scene.sjson, soil and
// grass under the sun, boulders and a machine block with copper pipes, drawn
// through the engine's WebGL2 renderer.
package surface

import "core:fmt"
import engine "../../engine"

page: engine.Scene_Page

main :: proc() {
	problem := engine.scene_page_init(&page, "canvas", #load("../../../data/materials/library.sjson"), #load("../../../data/demos/surface/scene.sjson"))
	if problem != "" do fmt.eprintln(problem)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.scene_page_step(&page, f32(delta_time))
	return true
}
