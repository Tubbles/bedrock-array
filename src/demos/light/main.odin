// The light demo: the scene of data/demos/light/scene.sjson, primitives in
// library materials under a sun and two lamps, drawn through the engine's
// WebGL2 renderer.
package light

import "core:fmt"
import engine "../../engine"

page: engine.Scene_Page

main :: proc() {
	problem := engine.scene_page_init(&page, "canvas", #load("../../../data/materials/library.sjson"), #load("../../../data/demos/light/scene.sjson"))
	if problem != "" do fmt.eprintln(problem)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.scene_page_step(&page)
	return true
}
