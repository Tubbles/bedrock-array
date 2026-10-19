package app

// The native app: a tech demo's scene through the engine's renderer, first
// person from the keyboard, the mouse and the gamepad, the plaques and the
// build stamp drawn by raylib. --demo <name> picks the demo (models, the
// default), --frames <n> stops after n frames (0, the default, runs until
// the window closes or Escape), --windowed keeps the window and the cursor
// instead of going borderless over the monitor with the cursor captured.

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import engine "../engine"
import gl "vendor:OpenGL"
import rl "shared:raylib"
import rlgl "shared:raylib/rlgl"

BUILD_INFO :: #config(BUILD_INFO, "dev")

APP_MOUSE_RADIANS_PER_PIXEL :: f32(0.003)
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
	windowed: bool,
}

// Parses the arguments after the program name. ok is false on an unknown
// argument or a missing or malformed value.
parse_options :: proc(arguments: []string) -> (options: Options, ok: bool) {
	options.demo = "models"
	index := 0
	for index < len(arguments) {
		switch arguments[index] {
		case "--windowed":
			options.windowed = true
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

// The page's keys (engine scene_page_key_from_code): opposite keys cancel.
keyboard_walk :: proc() -> [3]f32 {
	forward := any_key_down({.W, .UP})
	back := any_key_down({.S, .DOWN})
	left := any_key_down({.A, .LEFT})
	right := any_key_down({.D, .RIGHT})
	up := any_key_down({.E, .SPACE})
	down := any_key_down({.Q, .LEFT_SHIFT, .RIGHT_SHIFT, .LEFT_CONTROL, .RIGHT_CONTROL})
	return {key_axis(right, left), key_axis(up, down), key_axis(forward, back)}
}

frame_input :: proc() -> engine.Scene_Input {
	mouse := rl.GetMouseDelta()
	return {walk = keyboard_walk(), turn = {mouse.x, mouse.y} * APP_MOUSE_RADIANS_PER_PIXEL}
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

draw_frame :: proc(view: ^engine.Scene_View) {
	size := render_size()
	screen := screen_size()
	rl.BeginDrawing()
	engine.scene_view_draw(view, size.x, size.y)
	give_state_back_to_rlgl(size)
	draw_labels(view, screen)
	rl.DrawText(BUILD_INFO, 16, screen.y - 16 - LABEL_FONT_SIZE, LABEL_FONT_SIZE, TEXT_COLOR)
	rl.EndDrawing()
}

should_continue :: proc(options: Options, frames_drawn: int) -> bool {
	if rl.WindowShouldClose() || rl.IsKeyPressed(.ESCAPE) {
		return false
	}
	return options.frames == 0 || frames_drawn < options.frames
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
	if !ok || !known {
		fmt.eprintln("usage: bedrock-array [--demo light|surface|cave|models] [--frames <n>] [--windowed]")
		os.exit(2)
	}
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
		rl.DisableCursor()
	}
	rl.SetExitKey(.KEY_NULL)
	print_gl_info()
	gamepad_ready, gamepad_problem := gamepad_init()
	if !gamepad_ready do fmt.eprintfln("bedrock-array: no gamepad input: %s", gamepad_problem)
	gamepad_state: Gamepad_State
	view: engine.Scene_View
	size := render_size()
	problem := engine.scene_view_init(&view, MATERIAL_LIBRARY, demo.scene, material_textures, demo.meshes, f32(size.x) / f32(max(size.y, 1)))
	if problem != "" {
		fmt.eprintfln("bedrock-array: %s", problem)
		os.exit(1)
	}
	// The texture row flips and the shader strings of the native GL api are temp copies.
	free_all(context.temp_allocator)
	frames_drawn := 0
	for should_continue(options, frames_drawn) {
		delta_time := rl.GetFrameTime()
		input := frame_input()
		if gamepad_ready {
			// The turn is scaled here, so the step's limit on a long frame applies here too.
			gamepad_input := gamepad_scene_input(gamepad_poll(&gamepad_state), min(delta_time, engine.SCENE_VIEW_STEP_LIMIT))
			input.walk += gamepad_input.walk
			input.turn += gamepad_input.turn
		}
		engine.scene_view_step(&view, input, delta_time)
		draw_frame(&view)
		if frames_drawn == 0 do exit_on_gl_error()
		frames_drawn += 1
		free_all(context.temp_allocator)
	}
	engine.scene_view_destroy(&view)
	if gamepad_ready do gamepad_quit(&gamepad_state)
	rl.CloseWindow()
}
