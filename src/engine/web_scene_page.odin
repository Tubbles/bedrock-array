#+build js wasm32
package engine

import "base:runtime"
import "core:sys/wasm/js"
import gl "vendor:wasm/WebGL"

SCENE_PAGE_DRAG_RADIANS_PER_PIXEL :: f32(0.005)
SCENE_PAGE_PINCH_METRES_PER_PIXEL :: f32(0.02)
SCENE_PAGE_PINCH_ZOOM_PER_PIXEL :: f32(0.005)
SCENE_PAGE_WHEEL_ZOOM_PER_PIXEL :: f32(0.001)
SCENE_PAGE_STICK_DEAD_ZONE :: f32(0.15)
SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND :: f32(2)

// A pointer on the canvas: the mouse over it or a finger down. One alone turns the fly, two move it.
Scene_Page_Pointer :: struct {
	pointer_id: int,
	client:     [2]f32,
}

// A scene view on a canvas: the mouse or a finger looks, two fingers move, the keys or a gamepad walk.
Scene_Page :: struct {
	canvas_id:                   string,
	view:                        Scene_View,
	canvas_width, canvas_height: i32,
	aspect, pixel_ratio:         f32,
	active_pointers:             [2]Scene_Page_Pointer,
	active_pointer_count:        int,
	keys_held:                   bit_set[Scene_Page_Key],
	gamepad_index:               int,
	// A lone pointer's turn in radians since the last step.
	turn_pending:                [2]f32,
	// Two fingers' move in metres in the fly's frame since the last step.
	move_pending:                [3]f32,
	// The wheel's and two fingers' zoom since the last step, applied in orbit mode.
	zoom_pending:                f32,
	// A press of the C key, the pad's North button or right shoulder since the last step.
	cycle_pending:               bool,
	// A press of the pad's left shoulder since the last step.
	previous_pending:            bool,
	// The orbit's focus steps since the last step: the left arrow and the d-pad left count minus one, the right ones one.
	focus_pending:               int,
	// North was down on the last step, so a held button cycles once.
	north_held:                  bool,
	// The left and right shoulders were down on the last step.
	shoulders_held:              [2]bool,
	// The d-pad left and right were down on the last step.
	dpad_sides_held:             [2]bool,
	ready:                       bool,
}

// The page the label exports read, for the page's labels.js.
@(private = "file")
registered_page: ^Scene_Page

scene_page_register :: proc(page: ^Scene_Page) {
	registered_page = page
}

scene_page_init :: proc(page: ^Scene_Page, canvas_id: string, library_data, scene_data: []byte, textures, meshes: []runtime.Load_Directory_File) -> (problem: string) {
	page.canvas_id = canvas_id
	page.gamepad_index = -1
	scene_page_register(page)
	gl.CreateCurrentContextById(canvas_id, {})
	scene_page_resize(page)
	scene_page_listen(page)
	problem = scene_view_init(&page.view, library_data, scene_data, textures, meshes, page.aspect)
	if problem != "" do return problem
	page.ready = true
	return ""
}

// Draws nothing until the init has run through.
scene_page_step :: proc(page: ^Scene_Page, delta_time: f32) {
	if !page.ready do return
	input := Scene_Input {
		walk = scene_page_walk(page.keys_held),
		turn = page.turn_pending,
		move = page.move_pending,
		zoom = page.zoom_pending,
	}
	page.turn_pending = {}
	page.move_pending = {}
	page.zoom_pending = 0
	scene_page_gamepad(page, &input, min(delta_time, SCENE_VIEW_STEP_LIMIT))
	input.cycle_configuration = page.cycle_pending
	input.previous_configuration = page.previous_pending
	page.cycle_pending = false
	input.focus_step = page.focus_pending
	page.previous_pending = false
	page.focus_pending = 0
	scene_view_step(&page.view, input, delta_time)
	scene_view_draw(&page.view, page.canvas_width, page.canvas_height)
}

// The registered page's label at index, found false out of range.
@(private = "file")
scene_page_label :: proc "contextless" (index: i32) -> (label: Scene_Label, found: bool) {
	if registered_page == nil || index < 0 || int(index) >= len(registered_page.view.scene.labels) do return {}, false
	return registered_page.view.scene.labels[index], true
}

// The label's point in CSS pixels from the canvas's top left.
@(private = "file")
scene_page_label_screen :: proc "contextless" (index: i32) -> (pixel: [2]f32, visible: bool) {
	if registered_page == nil do return {}, false
	// The camera procedures take a context; the default one allocates nothing here.
	context = runtime.default_context()
	page := registered_page
	canvas := [2]f32{f32(page.canvas_width), f32(page.canvas_height)} / max(page.pixel_ratio, 1e-3)
	return scene_view_label_screen(&page.view, int(index), canvas)
}

@(export)
label_count :: proc "contextless" () -> i32 {
	if registered_page == nil do return 0
	return i32(len(registered_page.view.scene.labels))
}

@(export)
label_text_pointer :: proc "contextless" (index: i32) -> rawptr {
	label, _ := scene_page_label(index)
	return raw_data(label.text)
}

@(export)
label_text_length :: proc "contextless" (index: i32) -> i32 {
	label, _ := scene_page_label(index)
	return i32(len(label.text))
}

@(export)
label_screen_x :: proc "contextless" (index: i32) -> f32 {
	pixel, _ := scene_page_label_screen(index)
	return pixel.x
}

@(export)
label_screen_y :: proc "contextless" (index: i32) -> f32 {
	pixel, _ := scene_page_label_screen(index)
	return pixel.y
}

@(export)
label_visible :: proc "contextless" (index: i32) -> bool {
	_, visible := scene_page_label_screen(index)
	return visible
}

// The registered page's current configuration name, "" without a page.
@(private = "file")
scene_page_configuration_name :: proc "contextless" () -> string {
	if registered_page == nil do return ""
	context = runtime.default_context()
	return scene_view_configuration_name(&registered_page.view)
}

@(export)
configuration_count :: proc "contextless" () -> i32 {
	if registered_page == nil || !registered_page.ready do return 0
	context = runtime.default_context()
	return i32(scene_view_configuration_count(&registered_page.view))
}

@(export)
configuration_name_pointer :: proc "contextless" () -> rawptr {
	return raw_data(scene_page_configuration_name())
}

@(export)
configuration_name_length :: proc "contextless" () -> i32 {
	return i32(len(scene_page_configuration_name()))
}

// Cycles at once, so the button's text does not wait for a frame.
@(export)
cycle_configuration :: proc "contextless" () {
	if registered_page == nil || !registered_page.ready do return
	context = runtime.default_context()
	scene_view_step(&registered_page.view, {cycle_configuration = true}, 0)
}

// Steps back at once, as cycle_configuration.
@(export)
previous_configuration :: proc "contextless" () {
	if registered_page == nil || !registered_page.ready do return
	context = runtime.default_context()
	scene_view_step(&registered_page.view, {previous_configuration = true}, 0)
}

// Held keys walk the fly; opposite keys cancel.
@(private = "file")
scene_page_walk :: proc(keys: bit_set[Scene_Page_Key]) -> [3]f32 {
	return {
		f32(int(.Right in keys) - int(.Left in keys)),
		f32(int(.Up in keys) - int(.Down in keys)),
		f32(int(.Forward in keys) - int(.Back in keys)),
	}
}

// The standard mapping: the left stick walks, the right stick turns, the d-pad moves up and down, North and the right shoulder cycle the configuration, the left shoulder steps it back and the d-pad left and right step the orbit's focus.
@(private = "file")
scene_page_gamepad :: proc(page: ^Scene_Page, input: ^Scene_Input, delta_time: f32) {
	state: js.Gamepad_State
	if page.gamepad_index < 0 || !js.get_gamepad_state(page.gamepad_index, &state) || !state.connected do return
	left := [2]f32{stick_dead_zone(f32(state.axes[0]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[1]), SCENE_PAGE_STICK_DEAD_ZONE)}
	right := [2]f32{stick_dead_zone(f32(state.axes[2]), SCENE_PAGE_STICK_DEAD_ZONE), stick_dead_zone(f32(state.axes[3]), SCENE_PAGE_STICK_DEAD_ZONE)}
	vertical := f32(int(state.buttons[12].pressed) - int(state.buttons[13].pressed))
	input.walk += {left.x, vertical, -left.y}
	input.turn += right * SCENE_PAGE_STICK_TURN_RADIANS_PER_SECOND * delta_time
	north := state.buttons[3].pressed
	if north && !page.north_held do page.cycle_pending = true
	page.north_held = north
	shoulders := [2]bool{state.buttons[4].pressed, state.buttons[5].pressed}
	if shoulders[0] && !page.shoulders_held[0] do page.previous_pending = true
	if shoulders[1] && !page.shoulders_held[1] do page.cycle_pending = true
	page.shoulders_held = shoulders
	dpad_sides := [2]bool{state.buttons[14].pressed, state.buttons[15].pressed}
	if dpad_sides[0] && !page.dpad_sides_held[0] do page.focus_pending -= 1
	if dpad_sides[1] && !page.dpad_sides_held[1] do page.focus_pending += 1
	page.dpad_sides_held = dpad_sides
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
	js.add_event_listener(page.canvas_id, .Pointer_Leave, page, on_scene_page_pointer_up)
	js.add_event_listener(page.canvas_id, .Wheel, page, on_scene_page_wheel)
}

@(private = "file")
scene_page_resize :: proc(page: ^Scene_Page) {
	pixel_ratio := js.device_pixel_ratio()
	client_height := js.get_element_key_f64(page.canvas_id, "clientHeight")
	width := js.get_element_key_f64(page.canvas_id, "clientWidth") * pixel_ratio
	height := client_height * pixel_ratio
	js.set_element_key_f64(page.canvas_id, "width", width)
	js.set_element_key_f64(page.canvas_id, "height", height)
	page.canvas_width = i32(width)
	page.canvas_height = i32(height)
	page.pixel_ratio = f32(pixel_ratio)
	// From the whole pixels, as the renderer's viewport, so a plaque's point is the drawn one.
	page.aspect = f32(page.canvas_width) / f32(max(page.canvas_height, 1))
}

@(private = "file")
on_scene_page_resize :: proc(event: js.Event) {
	scene_page_resize((^Scene_Page)(event.user_data))
}

@(private = "file")
on_scene_page_key_down :: proc(event: js.Event) {
	if event.data.key.repeat do return
	page := (^Scene_Page)(event.user_data)
	if event.data.key.code == "KeyC" do page.cycle_pending = true
	// In orbit mode the side arrows step the focus instead of walking.
	if page.view.scene.camera_mode == .Orbit {
		if event.data.key.code == "ArrowLeft" {
			page.focus_pending -= 1
			return
		}
		if event.data.key.code == "ArrowRight" {
			page.focus_pending += 1
			return
		}
	}
	key, known := scene_page_key_from_code(event.data.key.code)
	if !known do return
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
on_scene_page_pointer_down :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	scene_page_add_pointer(page, event.data.mouse.pointer.pointer_id, scene_page_pointer_client(event))
}

// A lone pointer turns the fly, a finger dragging the scene and the mouse the view; two fingers move it by touch_pair_move and turn nothing. In orbit mode the mouse turns only while a button is down, a finger turns by its plain movement since it grabs the model, and two fingers zoom by their spread. Any pointer counts, not only the primary, so the finger left of a pair turns. A mouse joins on its first move over the canvas, a finger on its down.
@(private = "file")
on_scene_page_pointer_move :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	pointer := event.data.mouse.pointer
	client := scene_page_pointer_client(event)
	slot, found := scene_page_find_pointer(page, pointer.pointer_id)
	if !found {
		if pointer.pointer_type == .Mouse do scene_page_add_pointer(page, pointer.pointer_id, client)
		return
	}
	// The client delta, not the event's movement: odin.js stores the
	// browser's fractional movement as i64, and a value in (-1, 0) breaks.
	previous := [2][2]f32{page.active_pointers[0].client, page.active_pointers[1].client}
	movement := client - page.active_pointers[slot].client
	page.active_pointers[slot].client = client
	orbit := page.view.scene.camera_mode == .Orbit
	if page.active_pointer_count == 2 {
		current := [2][2]f32{page.active_pointers[0].client, page.active_pointers[1].client}
		if orbit {
			page.zoom_pending += touch_pair_spread(previous, current) * SCENE_PAGE_PINCH_ZOOM_PER_PIXEL
		} else {
			page.move_pending += touch_pair_move(previous, current, SCENE_PAGE_PINCH_METRES_PER_PIXEL)
		}
		return
	}
	if orbit {
		if pointer.pointer_type != .Mouse || event.data.mouse.buttons != {} do page.turn_pending += movement * SCENE_PAGE_DRAG_RADIANS_PER_PIXEL
		return
	}
	if pointer.pointer_type == .Mouse {
		page.turn_pending += movement * SCENE_PAGE_DRAG_RADIANS_PER_PIXEL
	} else {
		page.turn_pending += touch_turn(movement, SCENE_PAGE_DRAG_RADIANS_PER_PIXEL)
	}
}

// Zooms in either mode, fly ignores it. Scrolling up closes in.
@(private = "file")
on_scene_page_wheel :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	// Firefox counts a notch in lines, the others in pixels; a line is taken as 40 pixels, a page as 800.
	pixels_per_unit := [js.Delta_Mode]f32{.Pixel = 1, .Line = 40, .Page = 800}
	page.zoom_pending += -f32(event.data.wheel.delta.y) * pixels_per_unit[event.data.wheel.delta_mode] * SCENE_PAGE_WHEEL_ZOOM_PER_PIXEL
}

@(private = "file")
on_scene_page_pointer_up :: proc(event: js.Event) {
	page := (^Scene_Page)(event.user_data)
	slot, found := scene_page_find_pointer(page, event.data.mouse.pointer.pointer_id)
	if found do scene_page_remove_pointer(page, slot)
}
