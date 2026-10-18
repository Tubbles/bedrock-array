// The cave demo: the scene of data/demos/cave/scene.sjson, rock walls and
// stalagmites lit by glowing moss and fungus with no sun, drawn through the
// engine's WebGL2 renderer.
package cave

import "core:fmt"
import engine "../../engine"

page: engine.Scene_Page

main :: proc() {
	problem := engine.scene_page_init(&page, "canvas", #load("../../../data/materials/library.sjson"), #load("../../../data/demos/cave/scene.sjson"))
	if problem != "" do fmt.eprintln(problem)
}

@(export)
step :: proc(delta_time: f64) -> bool {
	engine.scene_page_step(&page, f32(delta_time))
	return true
}
