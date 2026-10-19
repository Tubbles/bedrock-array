package app

// One gamepad through SDL3's gamepad subsystem, never its video: raylib owns
// the window. The first pad SDL lists is opened and read once per frame.

import "core:c"
import "core:fmt"
import engine "../engine"
import sdl "vendor:sdl3"

APP_STICK_DEAD_ZONE :: f32(0.15)
SDL_AXIS_MAXIMUM :: f32(32767)

Gamepad_Button :: enum {
	South,
	East,
	West,
	North,
	Back,
	Start,
	Left_Shoulder,
	Right_Shoulder,
	Dpad_Up,
	Dpad_Down,
	Dpad_Left,
	Dpad_Right,
}

// The sticks past the dead zone, each axis minus one to one with y down as
// SDL reports it, the triggers zero to one.
Gamepad_Snapshot :: struct {
	connected: bool,
	left:      [2]f32,
	right:     [2]f32,
	triggers:  [2]f32,
	buttons:   bit_set[Gamepad_Button],
}

Gamepad_State :: struct {
	gamepad: ^sdl.Gamepad,
}

SDL_BUTTONS := [Gamepad_Button]sdl.GamepadButton {
	.South          = .SOUTH,
	.East           = .EAST,
	.West           = .WEST,
	.North          = .NORTH,
	.Back           = .BACK,
	.Start          = .START,
	.Left_Shoulder  = .LEFT_SHOULDER,
	.Right_Shoulder = .RIGHT_SHOULDER,
	.Dpad_Up        = .DPAD_UP,
	.Dpad_Down      = .DPAD_DOWN,
	.Dpad_Left      = .DPAD_LEFT,
	.Dpad_Right     = .DPAD_RIGHT,
}

gamepad_init :: proc() -> (ok: bool, problem: string) {
	sdl.SetHint(sdl.HINT_JOYSTICK_HIDAPI_STEAM, "1")
	// SDL's own handlers would turn SIGTERM into a quit event nobody reads.
	sdl.SetHint(sdl.HINT_NO_SIGNAL_HANDLERS, "1")
	if !sdl.Init({.GAMEPAD}) do return false, string(sdl.GetError())
	count: c.int
	joysticks := sdl.GetJoysticks(&count)
	sdl.free(joysticks)
	fmt.printfln("input: SDL sees %d joysticks", count)
	return true, ""
}

// Drops the open pad when it is gone, opens the first listed pad when none is open.
gamepad_connect :: proc(state: ^Gamepad_State) {
	// An unplugged pad keeps its handle until it is closed, so only this says it is gone.
	if state.gamepad != nil && !sdl.GamepadConnected(state.gamepad) {
		sdl.CloseGamepad(state.gamepad)
		state^ = {}
	}
	if state.gamepad != nil do return
	count: c.int
	gamepads := sdl.GetGamepads(&count)
	defer sdl.free(gamepads)
	if count == 0 do return
	state.gamepad = sdl.OpenGamepad(gamepads[0])
}

gamepad_axis :: proc(gamepad: ^sdl.Gamepad, axis: sdl.GamepadAxis) -> f32 {
	return engine.stick_dead_zone(clamp(f32(sdl.GetGamepadAxis(gamepad, axis)) / SDL_AXIS_MAXIMUM, -1, 1), APP_STICK_DEAD_ZONE)
}

gamepad_poll :: proc(state: ^Gamepad_State) -> Gamepad_Snapshot {
	sdl.UpdateGamepads()
	// Nothing reads SDL's events (raylib pumps GLFW), and a full queue sets an error on every push.
	sdl.FlushEvents(.FIRST, .LAST)
	gamepad_connect(state)
	if state.gamepad == nil do return {}
	snapshot := Gamepad_Snapshot {
		connected = true,
		left      = {gamepad_axis(state.gamepad, .LEFTX), gamepad_axis(state.gamepad, .LEFTY)},
		right     = {gamepad_axis(state.gamepad, .RIGHTX), gamepad_axis(state.gamepad, .RIGHTY)},
		triggers  = {gamepad_axis(state.gamepad, .LEFT_TRIGGER), gamepad_axis(state.gamepad, .RIGHT_TRIGGER)},
	}
	for sdl_button, button in SDL_BUTTONS {
		if sdl.GetGamepadButton(state.gamepad, sdl_button) do snapshot.buttons += {button}
	}
	return snapshot
}

gamepad_quit :: proc(state: ^Gamepad_State) {
	if state.gamepad != nil do sdl.CloseGamepad(state.gamepad)
	state^ = {}
	sdl.Quit()
}
