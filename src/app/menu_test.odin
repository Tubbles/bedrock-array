#+build !js
package app

import "core:testing"

@(test)
test_first_sentence :: proc(t: ^testing.T) {
	testing.expect_value(t, first_sentence("A cave. Move the mouse."), "A cave.")
	testing.expect_value(t, first_sentence("Version 1.5 of the scene. More."), "Version 1.5 of the scene.")
	testing.expect_value(t, first_sentence("No stop at all"), "No stop at all")
	testing.expect_value(t, first_sentence("One."), "One.")
}

@(test)
test_menu_step :: proc(t: ^testing.T) {
	state := Menu_State{}
	testing.expect_value(t, menu_step(&state, 3, {down = true}), Menu_Command.None)
	testing.expect_value(t, state.row, 1)
	menu_step(&state, 3, {down = true})
	menu_step(&state, 3, {down = true})
	testing.expect_value(t, state.row, 0)
	menu_step(&state, 3, {up = true})
	testing.expect_value(t, state.row, 2)
	testing.expect_value(t, menu_step(&state, 3, {select = true}), Menu_Command.Enter)
	testing.expect_value(t, menu_step(&state, 3, {back = true}), Menu_Command.Leave)
	testing.expect_value(t, state.row, 2)
}

@(test)
test_menu_edges :: proc(t: ^testing.T) {
	state := Menu_Edge_State{}
	held := Gamepad_Snapshot{connected = true, buttons = {.South}}
	testing.expect_value(t, menu_edges(&state, held), Menu_Input{select = true})
	testing.expect_value(t, menu_edges(&state, held), Menu_Input{})
	testing.expect_value(t, menu_edges(&state, {connected = true}), Menu_Input{})
	testing.expect_value(t, menu_edges(&state, {connected = true, buttons = {.East}}), Menu_Input{back = true})
	stick_down := Gamepad_Snapshot{connected = true, left = {0, 0.8}}
	testing.expect_value(t, menu_edges(&state, stick_down), Menu_Input{down = true})
	testing.expect_value(t, menu_edges(&state, stick_down), Menu_Input{})
	testing.expect_value(t, menu_edges(&state, {connected = true, left = {0, 0.3}}), Menu_Input{})
	testing.expect_value(t, menu_edges(&state, {connected = true, left = {0, -0.9}}), Menu_Input{up = true})
	testing.expect_value(t, menu_edges(&state, {connected = true, buttons = {.Dpad_Down}, left = {0, -0.9}}), Menu_Input{down = true})
}
