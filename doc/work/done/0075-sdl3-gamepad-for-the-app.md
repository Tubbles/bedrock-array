# 0075: The gamepad through SDL3 for the app

Status: landed (2026-10-19, e5512eb)

Goal: the gamepad flies the scene and later drives the menu: SDL3's gamepad subsystem, never its video (CLAUDE.md), the shape carried from Mine oh Belowed's input layer reduced to one pad and the standard buttons.

Verify:
- `./build.sh debug`, `check`, `test` and `smoke` pass; the smoke run prints `input: SDL sees <n> joysticks` and runs with none.
- `test_gamepad_scene_input` passes: a snapshot with the left stick half forward, the right stick a quarter right and the d-pad up gives the walk and turn the item states.

## Specification

- `src/app/gamepad.odin`: `Gamepad_Snapshot :: struct { connected: bool, left, right: [2]f32, triggers: [2]f32, buttons: bit_set[Gamepad_Button] }` with `Gamepad_Button :: enum { South, East, West, North, Back, Start, Left_Shoulder, Right_Shoulder, Dpad_Up, Dpad_Down, Dpad_Left, Dpad_Right }`; `gamepad_init() -> (ok: bool, problem: string)`: `sdl.SetHint(sdl.HINT_JOYSTICK_HIDAPI_STEAM, "1")`, `sdl.Init({.GAMEPAD})`, one line on stdout with the joystick count; `Gamepad_State :: struct { gamepad: ^sdl.Gamepad }`; `gamepad_poll(state: ^Gamepad_State) -> Gamepad_Snapshot`: `sdl.UpdateGamepads`, opens the first gamepad of `sdl.GetGamepads` when none is open (freeing the list), drops it when `sdl.GetGamepadFromID` says it is gone, reads the axes (`sdl.GetGamepadAxis`, `LEFTX` to `RIGHT_TRIGGER`) through `engine.stick_dead_zone` at `APP_STICK_DEAD_ZONE :: f32(0.15)` over 32767 and the buttons through `sdl.GetGamepadButton` (South to Dpad_Right as SDL names them); `gamepad_quit` (`sdl.CloseGamepad` when open, `sdl.Quit`).
- `src/app/gamepad_input.odin`: `gamepad_scene_input(snapshot: Gamepad_Snapshot, delta_time: f32) -> engine.Scene_Input`, pure: walk x from the left stick's x, walk z from minus its y, walk y from the d-pad up minus down, turn from the right stick times `APP_STICK_TURN_RADIANS_PER_SECOND :: f32(2) * delta_time` (x then y, the page's signs); `src/app/gamepad_input_test.odin` with the test above.
- `src/app/main.odin`: `gamepad_init` after the window (a failure printed, the app goes on without a pad), the snapshot each frame, its scene input added to the keyboard's, `gamepad_quit` at the end.
- `doc/build.md` or a new `doc/input.md`: one paragraph on the pad through SDL3, the hint, the first pad opened, the standard mapping.
