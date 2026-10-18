// The hello demo: clears a WebGL2 canvas to a colour that changes with a
// tap or a click.
package hello

import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

colour_index: int
colours := [3][4]f32{{0.10, 0.12, 0.16, 1}, {0.55, 0.30, 0.10, 1}, {0.12, 0.40, 0.30, 1}}

main :: proc() {
	gl.CreateCurrentContextById("canvas", {})
	resize_canvas()
	js.add_event_listener("canvas", .Pointer_Down, nil, on_pointer_down)
	js.add_window_event_listener(.Resize, nil, on_resize)
}

resize_canvas :: proc() {
	pixel_ratio := js.device_pixel_ratio()
	width := js.get_element_key_f64("canvas", "clientWidth") * pixel_ratio
	height := js.get_element_key_f64("canvas", "clientHeight") * pixel_ratio
	js.set_element_key_f64("canvas", "width", width)
	js.set_element_key_f64("canvas", "height", height)
	gl.Viewport(0, 0, i32(width), i32(height))
}

on_pointer_down :: proc(event: js.Event) {
	colour_index = (colour_index + 1) % len(colours)
}

on_resize :: proc(event: js.Event) {
	resize_canvas()
}

@(export)
step :: proc(delta_time: f64) -> bool {
	colour := colours[colour_index]
	gl.ClearColor(colour[0], colour[1], colour[2], colour[3])
	gl.Clear(u32(gl.COLOR_BUFFER_BIT))
	return true
}
