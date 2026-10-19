#+build !js
package app

import "core:testing"
import engine "../engine"

@(test)
test_lod_panel_moves_and_wraps :: proc(t: ^testing.T) {
	panel: Lod_Panel
	settings := engine.LOD_SETTINGS_DEFAULT
	lod_panel_step(&panel, &settings, {down = true})
	testing.expect_value(t, panel.row, 0)
	lod_panel_step(&panel, &settings, {toggle = true})
	testing.expect(t, panel.open)
	lod_panel_step(&panel, &settings, {up = true})
	testing.expect_value(t, panel.row, len(Lod_Panel_Row) - 1)
	lod_panel_step(&panel, &settings, {down = true})
	testing.expect_value(t, panel.row, 0)
	lod_panel_step(&panel, &settings, {down = true})
	testing.expect_value(t, panel.row, 1)
	lod_panel_step(&panel, &settings, {toggle = true})
	testing.expect(t, !panel.open)
	testing.expect_value(t, settings, engine.LOD_SETTINGS_DEFAULT)
}

@(test)
test_lod_panel_adjusts_within_limits :: proc(t: ^testing.T) {
	panel := Lod_Panel{open = true}
	settings := engine.LOD_SETTINGS_DEFAULT
	lod_panel_step(&panel, &settings, {right = true})
	testing.expect(t, abs(settings.pixels_per_triangle - 8 * 1.41421356) < 1e-4)
	for _ in 0 ..< 20 do lod_panel_step(&panel, &settings, {right = true})
	testing.expect_value(t, settings.pixels_per_triangle, LOD_PANEL_PIXELS_MAXIMUM)
	for _ in 0 ..< 20 do lod_panel_step(&panel, &settings, {left = true})
	testing.expect_value(t, settings.pixels_per_triangle, LOD_PANEL_PIXELS_MINIMUM)
	lod_panel_step(&panel, &settings, {down = true, right = true})
	testing.expect(t, abs(settings.hysteresis - 0.2) < 1e-5)
	for _ in 0 ..< 20 do lod_panel_step(&panel, &settings, {right = true})
	testing.expect(t, abs(settings.hysteresis - LOD_PANEL_HYSTERESIS_MAXIMUM) < 1e-5)
	for _ in 0 ..< 20 do lod_panel_step(&panel, &settings, {left = true})
	testing.expect_value(t, settings.hysteresis, 0)
	lod_panel_step(&panel, &settings, {down = true, left = true})
	testing.expect(t, abs(settings.crossfade_seconds - 0.3) < 1e-5)
	for _ in 0 ..< 30 do lod_panel_step(&panel, &settings, {right = true})
	testing.expect(t, abs(settings.crossfade_seconds - LOD_PANEL_CROSSFADE_MAXIMUM) < 1e-5)
	lod_panel_step(&panel, &settings, {down = true, right = true})
	testing.expect(t, settings.tint)
	lod_panel_step(&panel, &settings, {down = true, left = true})
	testing.expect(t, settings.freeze)
	lod_panel_step(&panel, &settings, {left = true})
	testing.expect(t, !settings.freeze)
}

@(test)
test_lod_panel_reset_restores_the_default :: proc(t: ^testing.T) {
	panel := Lod_Panel{open = true}
	settings := engine.Lod_Settings{pixels_per_triangle = 32, hysteresis = 0.5, crossfade_seconds = 2, freeze = true, tint = true}
	lod_panel_step(&panel, &settings, {reset = true})
	testing.expect_value(t, settings.pixels_per_triangle, engine.LOD_SETTINGS_DEFAULT.pixels_per_triangle)
	testing.expect_value(t, settings.hysteresis, f32(0.5))
	for _ in 0 ..< 4 do lod_panel_step(&panel, &settings, {down = true, reset = true})
	testing.expect_value(t, settings, engine.LOD_SETTINGS_DEFAULT)
}
