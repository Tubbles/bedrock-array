package app

// The native app: a menu of the tech demos, and a demo's scene through the
// engine's renderer, first person from the keyboard, the mouse and the
// gamepad, the plaques and the build stamp drawn by raylib. --demo <name>
// starts in that demo instead of the menu, --frames <n> stops after n frames
// (0, the default, runs until the window closes or the menu is left),
// --windowed keeps the window and the cursor instead of going borderless over
// the monitor with the cursor captured in a demo. --view and --configuration
// set the demo's camera and configuration, --shot <path> writes the scene alone
// to a PNG on the last frame and exits. --edit <machine> starts in the
// pipeline editor of that machine, whose shot keeps the plaques and the step list.

import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:strconv"
import "core:strings"
import engine "../engine"
import gl "vendor:OpenGL"
import rl "shared:raylib"
import rlgl "shared:raylib/rlgl"

BUILD_INFO :: #config(BUILD_INFO, "dev")

APP_MOUSE_RADIANS_PER_PIXEL :: f32(0.003)
APP_WHEEL_ZOOM_PER_NOTCH :: f32(0.1)
LABEL_FONT_SIZE :: 20
LABEL_PADDING :: 6
// Points, the page's 9rem at this font size.
LABEL_MAXIMUM_WIDTH :: 180

BACKGROUND_COLOR :: rl.Color{30, 30, 34, 255}
TEXT_COLOR :: rl.Color{220, 220, 220, 255}
LABEL_TEXT_COLOR :: rl.WHITE
LABEL_BACKGROUND_COLOR :: rl.Color{0, 0, 0, 160}

Options :: struct {
	demo:     string,
	frames:   int,
	windowed:      bool,
	shot:          string,
	view:          Maybe(engine.Orbit),
	configuration: int,
	// A scene and its meshes read from this directory instead of an embedded demo.
	scene_directory: string,
	// The sun follows the camera, so whichever face a shot looks at is lit.
	camera_light: bool,
	// The machine whose pipeline the editor opens at start.
	edit: string,
}

// The direction the camera light travels: along the view, from above and
// to the left of the camera, so faces are lit with some modelling shade.
camera_light_direction :: proc(camera: engine.Camera) -> [3]f32 {
	forward := linalg.normalize(camera.target - camera.position)
	right := linalg.normalize(linalg.cross(forward, camera.up))
	return linalg.normalize(forward - 0.6 * camera.up + 0.4 * right)
}

// Six numbers separated by commas: yaw, pitch, distance, then the target's x, y and z.
parse_view :: proc(text: string) -> (orbit: engine.Orbit, ok: bool) {
	parts := strings.split(text, ",", context.temp_allocator)
	if len(parts) != 6 do return orbit, false
	numbers: [6]f32
	for part, index in parts {
		numbers[index] = strconv.parse_f32(part) or_return
	}
	return engine.Orbit{target = {numbers[3], numbers[4], numbers[5]}, yaw = numbers[0], pitch = numbers[1], distance = numbers[2]}, true
}

// Parses the arguments after the program name. ok is false on an unknown
// argument or a missing or malformed value.
parse_options :: proc(arguments: []string) -> (options: Options, ok: bool) {
	index := 0
	for index < len(arguments) {
		switch arguments[index] {
		case "--camera-light":
			options.camera_light = true
		case "--windowed":
			options.windowed = true
		case "--scene-directory":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			options.scene_directory = arguments[index]
		case "--edit":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			options.edit = arguments[index]
		case "--demo":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			options.demo = arguments[index]
		case "--frames":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			frames, parsed := strconv.parse_int(arguments[index])
			if !parsed || frames < 0 {
				return options, false
			}
			options.frames = frames
		case "--shot":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			options.shot = arguments[index]
		case "--view":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			orbit, parsed := parse_view(arguments[index])
			if !parsed {
				return options, false
			}
			options.view = orbit
		case "--configuration":
			index += 1
			if index >= len(arguments) {
				return options, false
			}
			configuration, parsed := strconv.parse_int(arguments[index])
			if !parsed || configuration < 0 {
				return options, false
			}
			options.configuration = configuration
		case:
			return options, false
		}
		index += 1
	}
	return options, true
}

// A nil string reads as unknown.
gl_string :: proc(name: u32) -> string {
	value := string(gl.GetString(name))
	return value if value != "" else "unknown"
}

print_gl_info :: proc() {
	fmt.printfln("gl vendor: %s", gl_string(gl.VENDOR))
	fmt.printfln("gl renderer: %s", gl_string(gl.RENDERER))
	fmt.printfln("gl version: %s", gl_string(gl.VERSION))
}

// Through GLFW's loader, so the app does not link libGL.
load_gl :: proc() {
	gl.load_up_to(3, 3, proc(pointer: rawptr, name: cstring) {
		(^rawptr)(pointer)^ = rl.glfwGetProcAddress(name)
	})
}

// In pixels, for the GL drawing.
render_size :: proc() -> [2]i32 {
	return {i32(rl.GetRenderWidth()), i32(rl.GetRenderHeight())}
}

// In points, for raylib's 2D drawing, which scales by the display's scale.
screen_size :: proc() -> [2]i32 {
	return {i32(rl.GetScreenWidth()), i32(rl.GetScreenHeight())}
}

key_axis :: proc(positive, negative: bool) -> f32 {
	return f32(int(positive)) - f32(int(negative))
}

any_key_down :: proc(keys: []rl.KeyboardKey) -> bool {
	for key in keys {
		if rl.IsKeyDown(key) do return true
	}
	return false
}

// The page's keys (engine scene_page_key_from_code): opposite keys cancel. Without side_arrows_walk only A and D walk sideways, without forward_arrows_walk only W and S walk forward and back.
keyboard_walk :: proc(side_arrows_walk, forward_arrows_walk: bool) -> [3]f32 {
	forward := rl.IsKeyDown(.W) || (forward_arrows_walk && rl.IsKeyDown(.UP))
	back := rl.IsKeyDown(.S) || (forward_arrows_walk && rl.IsKeyDown(.DOWN))
	left := any_key_down({.A}) || (side_arrows_walk && rl.IsKeyDown(.LEFT))
	right := any_key_down({.D}) || (side_arrows_walk && rl.IsKeyDown(.RIGHT))
	up := any_key_down({.E, .SPACE})
	down := any_key_down({.Q, .LEFT_SHIFT, .RIGHT_SHIFT})
	return {key_axis(right, left), key_axis(up, down), key_axis(forward, back)}
}

// In orbit mode the mouse turns only while its left button is down, the wheel zooms and the side arrows step the focus instead of walking. While the panel is open the arrows drive it and neither walk nor step the focus.
frame_input :: proc(camera_mode: engine.Scene_Camera_Mode, panel_open: bool) -> engine.Scene_Input {
	mouse := rl.GetMouseDelta()
	input := engine.Scene_Input {
		walk = keyboard_walk(camera_mode != .Orbit && !panel_open, !panel_open),
		turn = {mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL,
		cycle_configuration = rl.IsKeyPressed(.C),
	}
	if !panel_open do input.focus_step = int(rl.IsKeyPressed(.RIGHT)) - int(rl.IsKeyPressed(.LEFT))
	if camera_mode == .Orbit {
		if !rl.IsMouseButtonDown(.LEFT) do input.turn = {}
		input.zoom = rl.GetMouseWheelMove() * APP_WHEEL_ZOOM_PER_NOTCH
	}
	return input
}

// The renderer sets GL state behind rlgl's back. rlgl.SetBlendMode skips a
// mode its cache already holds, so the blend function is set directly.
give_state_back_to_rlgl :: proc(size: [2]i32) {
	rlgl.DisableDepthTest()
	rlgl.EnableBackfaceCulling()
	rlgl.DisableVertexArray()
	rlgl.DisableShader()
	rlgl.DisableFramebuffer()
	rlgl.DisableTexture()
	rlgl.EnableColorBlend()
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	rlgl.Viewport(0, 0, size.x, size.y)
}

measure_label_text :: proc(text: string) -> int {
	return int(rl.MeasureText(strings.clone_to_cstring(text, context.temp_allocator), LABEL_FONT_SIZE))
}

// Wrapped, each line centred on the point's x, the block's bottom at the
// point, white on one dark translucent plaque.
draw_label :: proc(text: string, point: [2]f32) {
	lines := wrap_words(text, LABEL_MAXIMUM_WIDTH, measure_label_text)
	widest := 0
	for line in lines do widest = max(widest, measure_label_text(line))
	top := i32(point.y) - i32(len(lines)) * LABEL_FONT_SIZE
	left := i32(point.x) - i32(widest) / 2
	rl.DrawRectangle(left - LABEL_PADDING, top - LABEL_PADDING, i32(widest) + 2 * LABEL_PADDING, i32(len(lines)) * LABEL_FONT_SIZE + 2 * LABEL_PADDING, LABEL_BACKGROUND_COLOR)
	for line, index in lines {
		x := i32(point.x) - i32(measure_label_text(line)) / 2
		y := top + i32(index) * LABEL_FONT_SIZE
		rl.DrawText(strings.clone_to_cstring(line, context.temp_allocator), x, y, LABEL_FONT_SIZE, LABEL_TEXT_COLOR)
	}
}

// The labels' points in screen points.
draw_labels :: proc(view: ^engine.Scene_View, size: [2]i32) {
	canvas := [2]f32{f32(size.x), f32(size.y)}
	for label, index in view.scene.labels {
		pixel, visible := engine.scene_view_label_screen(view, index, canvas)
		if visible do draw_label(label.text, pixel)
	}
}

// Bottom right, at the stamp's margin, only for a scene with configurations to cycle.
draw_configuration_name :: proc(view: ^engine.Scene_View, screen: [2]i32) {
	if engine.scene_view_configuration_count(view) <= 1 do return
	text := fmt.ctprintf("Y LB RB: %s", engine.scene_view_configuration_name(view))
	x := screen.x - 16 - rl.MeasureText(text, LABEL_FONT_SIZE)
	rl.DrawText(text, x, screen.y - 16 - LABEL_FONT_SIZE, LABEL_FONT_SIZE, TEXT_COLOR)
}

// In a shot only the scene is drawn. A capture_path names the PNG the frame is
// written to; written is false when that export fails.
draw_frame :: proc(view: ^engine.Scene_View, panel: Lod_Panel, in_shot: bool, capture_path: string) -> (written: bool) {
	size := render_size()
	screen := screen_size()
	rl.BeginDrawing()
	engine.scene_view_draw(view, size.x, size.y)
	give_state_back_to_rlgl(size)
	if !in_shot {
		draw_labels(view, screen)
		rl.DrawText(BUILD_INFO, 16, screen.y - 16 - LABEL_FONT_SIZE, LABEL_FONT_SIZE, TEXT_COLOR)
		draw_configuration_name(view, screen)
		lod_panel_draw(panel, view)
	}
	written = true
	if capture_path != "" do written = capture_screen(capture_path)
	rl.EndDrawing()
	return written
}

capture_screen :: proc(path: string) -> bool {
	image := rl.LoadImageFromScreen()
	defer rl.UnloadImage(image)
	return rl.ExportImage(image, strings.clone_to_cstring(path, context.temp_allocator))
}

draw_menu_frame :: proc(menu: Menu_State, rows: []Demo) {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)
	menu_draw(menu, rows, BUILD_INFO)
	rl.EndDrawing()
}

should_continue :: proc(options: Options, frames_drawn: int) -> bool {
	if rl.WindowShouldClose() {
		return false
	}
	return options.frames == 0 || frames_drawn < options.frames
}

keyboard_menu_input :: proc() -> Menu_Input {
	return {up = rl.IsKeyPressed(.UP), down = rl.IsKeyPressed(.DOWN), select = rl.IsKeyPressed(.ENTER), back = rl.IsKeyPressed(.ESCAPE)}
}

// The view destroyed first, so a demo left earlier is freed. The cursor is
// captured unless the window was asked for.
enter_demo :: proc(view: ^engine.Scene_View, demo: Demo, options: Options) {
	engine.scene_view_destroy(view)
	size := render_size()
	problem := engine.scene_view_init(view, MATERIAL_LIBRARY, demo.scene, material_textures, demo.meshes, f32(size.x) / f32(max(size.y, 1)))
	if problem != "" {
		fmt.eprintfln("bedrock-array: %s", problem)
		os.exit(1)
	}
	// The texture row flips and the shader strings of the native GL api are temp copies.
	free_all(context.temp_allocator)
	if orbit, has_view := options.view.?; has_view {
		view.orbit = orbit
		view.fly = engine.fly_from_orbit(orbit)
	}
	view.configuration = options.configuration % engine.scene_view_configuration_count(view)
	if !options.windowed do rl.DisableCursor()
}

// The menu is driven by the pad, so the pointer stays hidden; EnableCursor
// alone would show it warped to the window's centre.
leave_demo :: proc(view: ^engine.Scene_View, options: Options) {
	engine.scene_view_destroy(view)
	if !options.windowed {
		rl.EnableCursor()
		rl.HideCursor()
	}
}

// The cursor is captured, as in a demo, unless the window was asked for.
// --view places the fly camera.
enter_editor :: proc(editor: ^Editor, machine: string, options: Options) {
	size := render_size()
	problem := editor_open(editor, machine, f32(size.x) / f32(max(size.y, 1)))
	if problem != "" {
		fmt.eprintfln("bedrock-array: editor: %s", problem)
		os.exit(1)
	}
	free_all(context.temp_allocator)
	if orbit, has_view := options.view.?; has_view do editor.fly = engine.fly_from_orbit(orbit)
	if !options.windowed do rl.DisableCursor()
}

// The pointer stays hidden for the menu, as when leaving a demo.
leave_editor :: proc(editor: ^Editor, options: Options) {
	editor_destroy(editor)
	if !options.windowed {
		rl.EnableCursor()
		rl.HideCursor()
	}
}

// Read once after the first frame, so the smoke run fails on a GL error.
exit_on_gl_error :: proc() {
	error := gl.GetError()
	if error != gl.NO_ERROR {
		fmt.eprintfln("gl error 0x%X", error)
		os.exit(1)
	}
}

main :: proc() {
	options, ok := parse_options(os.args[1:])
	demo, known := demo_by_name(options.demo)
	if options.scene_directory != "" {
		demo, known = demo_from_directory(options.scene_directory)
		if !known do fmt.eprintfln("bedrock-array: no scene.sjson and meshes/ under %s", options.scene_directory)
	}
	editing := options.edit != "" && !known
	if !ok || ((options.demo != "" || options.scene_directory != "") && !known) || (options.shot != "" && !known && !editing) {
		fmt.eprintln("usage: bedrock-array [--demo light|surface|cave|models|decimation|parts|lod] [--edit <machine>] [--frames <n>] [--windowed] [--view yaw,pitch,distance,x,y,z] [--configuration <n>] [--scene-directory <dir>] [--camera-light] [--shot <path> (with a demo or --edit)]")
		os.exit(2)
	}
	if options.shot != "" do options.frames = max(options.frames, 3)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .VSYNC_HINT})
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(1280, 720, "Bedrock Array")
	if !rl.IsWindowReady() {
		fmt.eprintln("bedrock-array: the window did not open")
		os.exit(1)
	}
	load_gl()
	if !options.windowed {
		rl.ToggleBorderlessWindowed()
		rl.HideCursor()
	}
	rl.SetExitKey(.KEY_NULL)
	print_gl_info()
	gamepad_ready, gamepad_problem := gamepad_init()
	if !gamepad_ready do fmt.eprintfln("bedrock-array: no gamepad input: %s", gamepad_problem)
	gamepad_state: Gamepad_State
	edge_state: Menu_Edge_State
	menu: Menu_State
	view: engine.Scene_View
	lod_panel: Lod_Panel
	editor: Editor
	editor_triggers: [2]f32
	menu_rows := make([dynamic]Demo)
	defer delete(menu_rows)
	append(&menu_rows, ..DEMOS[:])
	append(&menu_rows, EDITOR_MENU_ENTRY)
	screen := App_Screen.Menu
	if known {
		enter_demo(&view, demo, options)
		screen = .Demo
	} else if editing {
		enter_editor(&editor, options.edit, options)
		screen = .Editor
	}
	frames_drawn := 0
	for should_continue(options, frames_drawn) {
		delta_time := rl.GetFrameTime()
		snapshot: Gamepad_Snapshot
		if gamepad_ready do snapshot = gamepad_poll(&gamepad_state)
		start_pressed := .Start in snapshot.buttons && .Start not_in edge_state.buttons
		north_pressed := .North in snapshot.buttons && .North not_in edge_state.buttons
		left_shoulder_pressed := .Left_Shoulder in snapshot.buttons && .Left_Shoulder not_in edge_state.buttons
		right_shoulder_pressed := .Right_Shoulder in snapshot.buttons && .Right_Shoulder not_in edge_state.buttons
		dpad_left_pressed := .Dpad_Left in snapshot.buttons && .Dpad_Left not_in edge_state.buttons
		dpad_right_pressed := .Dpad_Right in snapshot.buttons && .Dpad_Right not_in edge_state.buttons
		dpad_up_pressed := .Dpad_Up in snapshot.buttons && .Dpad_Up not_in edge_state.buttons
		dpad_down_pressed := .Dpad_Down in snapshot.buttons && .Dpad_Down not_in edge_state.buttons
		back_pressed := .Back in snapshot.buttons && .Back not_in edge_state.buttons
		south_pressed := .South in snapshot.buttons && .South not_in edge_state.buttons
		pad_pressed := snapshot.buttons - edge_state.buttons
		menu_input := menu_input_merge(keyboard_menu_input(), menu_edges(&edge_state, snapshot))
		if screen == .Menu {
			command := menu_step(&menu, len(menu_rows), menu_input)
			if command == .Leave do break
			if command == .Enter && menu.row == len(DEMOS) {
				enter_editor(&editor, EDITOR_MENU_MACHINE, options)
				screen = .Editor
			} else if command == .Enter {
				enter_demo(&view, DEMOS[menu.row], options)
				screen = .Demo
			}
		} else if screen == .Demo && (menu_input.back || start_pressed) {
			leave_demo(&view, options)
			lod_panel.open = false
			screen = .Menu
		}
		capture_path := options.shot if options.shot != "" && frames_drawn == options.frames - 1 else ""
		if screen == .Menu {
			draw_menu_frame(menu, menu_rows[:])
		} else if screen == .Editor {
			editor_input := editor_read_input(editor_mode(&editor), editor.frames >= EDITOR_MOUSE_SETTLE_FRAMES, snapshot, pad_pressed, &editor_triggers, delta_time)
			if editor_step(&editor, editor_input) == .Leave {
				leave_editor(&editor, options)
				screen = .Menu
				// Drawn in this frame, as leaving a demo is: raylib updates the keys
				// when a frame ends, so a frame without one would hand the menu the
				// same Escape again and quit the game.
				draw_menu_frame(menu, menu_rows[:])
			} else if !draw_editor_frame(&editor, options.shot != "", capture_path) {
				fmt.eprintfln("bedrock-array: the shot could not be written to %s", options.shot)
				os.exit(1)
			}
			if capture_path != "" do fmt.printfln("shot: %s", capture_path)
		} else {
			if lod_panel_available(&view) {
				lod_panel_step(&lod_panel, &view.lod, {
					toggle = back_pressed || rl.IsKeyPressed(.TAB),
					up = dpad_up_pressed || rl.IsKeyPressed(.UP),
					down = dpad_down_pressed || rl.IsKeyPressed(.DOWN),
					left = dpad_left_pressed || rl.IsKeyPressed(.LEFT),
					right = dpad_right_pressed || rl.IsKeyPressed(.RIGHT),
					reset = south_pressed || rl.IsKeyPressed(.ENTER),
				})
			}
			input := frame_input(view.scene.camera_mode, lod_panel.open)
			// The turn is scaled here, so the step's limit on a long frame applies here too.
			gamepad_input := gamepad_scene_input(snapshot, min(delta_time, engine.SCENE_VIEW_STEP_LIMIT))
			// While the panel is open the d-pad drives it and does not rise, sink or step the focus.
			if lod_panel.open do gamepad_input.walk.y = 0
			input.walk += gamepad_input.walk
			input.turn += gamepad_input.turn
			input.cycle_configuration = input.cycle_configuration || north_pressed || right_shoulder_pressed
			input.previous_configuration = left_shoulder_pressed
			if !lod_panel.open do input.focus_step += int(dpad_right_pressed) - int(dpad_left_pressed)
			if rl.IsKeyPressed(.T) do view.lod.tint = !view.lod.tint
			if rl.IsKeyPressed(.F) do view.lod.freeze = !view.lod.freeze
			engine.scene_view_step(&view, input, delta_time)
			if options.camera_light do view.scene.sun.direction = camera_light_direction(engine.scene_view_camera(&view))
			if !draw_frame(&view, lod_panel, options.shot != "", capture_path) {
				fmt.eprintfln("bedrock-array: the shot could not be written to %s", options.shot)
				os.exit(1)
			}
			if capture_path != "" do fmt.printfln("shot: %s", capture_path)
		}
		if frames_drawn == 0 do exit_on_gl_error()
		frames_drawn += 1
		free_all(context.temp_allocator)
	}
	engine.scene_view_destroy(&view)
	if screen == .Editor do editor_destroy(&editor)
	if gamepad_ready do gamepad_quit(&gamepad_state)
	rl.CloseWindow()
}
