package app

// The native app: a window that draws the title and the build stamp.
// --frames <n> stops after n frames (0, the default, runs until the window
// closes), --windowed keeps the window instead of going borderless over
// the monitor.

import "core:fmt"
import "core:os"
import "core:strconv"
import rl "shared:raylib"

BUILD_INFO :: #config(BUILD_INFO, "dev")

GL_VENDOR :: 0x1F00
GL_RENDERER :: 0x1F01
GL_VERSION :: 0x1F02

BACKGROUND_COLOR :: rl.Color{30, 30, 34, 255}
TEXT_COLOR :: rl.Color{220, 220, 220, 255}

Options :: struct {
	frames:   int,
	windowed: bool,
}

Gl_Get_String :: #type proc "c" (name: u32) -> cstring

// Parses the arguments after the program name. ok is false on an unknown
// argument or a missing or malformed frame count.
parse_options :: proc(arguments: []string) -> (options: Options, ok: bool) {
	index := 0
	for index < len(arguments) {
		switch arguments[index] {
		case "--windowed":
			options.windowed = true
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

// A nil procedure or a nil string reads as unknown.
gl_string :: proc(get_string: Gl_Get_String, name: u32) -> string {
	if get_string == nil {
		return "unknown"
	}
	value := string(get_string(name))
	return value if value != "" else "unknown"
}

// Through GLFW's loader, so the app does not link libGL.
print_gl_info :: proc() {
	get_string := cast(Gl_Get_String)rl.glfwGetProcAddress("glGetString")
	fmt.printfln("gl vendor: %s", gl_string(get_string, GL_VENDOR))
	fmt.printfln("gl renderer: %s", gl_string(get_string, GL_RENDERER))
	fmt.printfln("gl version: %s", gl_string(get_string, GL_VERSION))
}

draw_frame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COLOR)
	rl.DrawText("Bedrock Array", 40, 40, 40, TEXT_COLOR)
	rl.DrawText(BUILD_INFO, 40, 96, 20, TEXT_COLOR)
	rl.EndDrawing()
}

should_continue :: proc(options: Options, frames_drawn: int) -> bool {
	if rl.WindowShouldClose() {
		return false
	}
	return options.frames == 0 || frames_drawn < options.frames
}

main :: proc() {
	options, ok := parse_options(os.args[1:])
	if !ok {
		fmt.eprintln("usage: bedrock-array [--frames <n>] [--windowed]")
		os.exit(2)
	}
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_HIGHDPI, .VSYNC_HINT})
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(1280, 720, "Bedrock Array")
	if !rl.IsWindowReady() {
		fmt.eprintln("bedrock-array: the window did not open")
		os.exit(1)
	}
	if !options.windowed {
		rl.ToggleBorderlessWindowed()
	}
	rl.SetExitKey(.KEY_NULL)
	print_gl_info()
	frames_drawn := 0
	for should_continue(options, frames_drawn) {
		draw_frame()
		frames_drawn += 1
	}
	rl.CloseWindow()
}
