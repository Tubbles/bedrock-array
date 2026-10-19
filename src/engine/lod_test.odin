#+build !js
package engine

import "core:math"
import "core:testing"

@(private = "file")
LEVEL_TRIANGLE_COUNTS := []int{1000, 500, 100}

@(test)
test_lod_wanted_picks_the_finest_that_fits :: proc(t: ^testing.T) {
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 8000, 8), 0)
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 7999, 8), 1)
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 4000, 8), 1)
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 800, 8), 2)
}

@(test)
test_lod_wanted_falls_to_the_coarsest :: proc(t: ^testing.T) {
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 10, 8), 2)
	testing.expect_value(t, lod_wanted(LEVEL_TRIANGLE_COUNTS, 0, 8), 2)
}

@(test)
test_lod_choose_holds_inside_the_band :: proc(t: ^testing.T) {
	// Level 1 wants 4000 pixels and level 0 wants 8000.
	testing.expect_value(t, lod_choose(1, LEVEL_TRIANGLE_COUNTS, 8500, 8, 0.15), 1)
	testing.expect_value(t, lod_choose(0, LEVEL_TRIANGLE_COUNTS, 7500, 8, 0.15), 0)
	testing.expect_value(t, lod_choose(2, LEVEL_TRIANGLE_COUNTS, 4300, 8, 0.15), 2)
}

@(test)
test_lod_choose_switches_outside_the_band :: proc(t: ^testing.T) {
	testing.expect_value(t, lod_choose(1, LEVEL_TRIANGLE_COUNTS, 9500, 8, 0.15), 0)
	testing.expect_value(t, lod_choose(0, LEVEL_TRIANGLE_COUNTS, 6500, 8, 0.15), 1)
	testing.expect_value(t, lod_choose(0, LEVEL_TRIANGLE_COUNTS, 100, 8, 0.15), 2)
	testing.expect_value(t, lod_choose(2, LEVEL_TRIANGLE_COUNTS, 20000, 8, 0.15), 0)
	testing.expect_value(t, lod_choose(7, LEVEL_TRIANGLE_COUNTS, 100, 8, 0.15), 2)
	testing.expect_value(t, lod_choose(-3, LEVEL_TRIANGLE_COUNTS, 20000, 8, 0.15), 0)
}

@(test)
test_lod_screen_pixels_halves_with_double_distance :: proc(t: ^testing.T) {
	camera := Camera {
		position = {0, 0, 0},
		target = {0, 0, -1},
		up = {0, 1, 0},
		vertical_fov_radians = math.PI / 2,
		near = 0.1,
		far = 100,
	}
	near_area := lod_screen_pixels(camera, 1000, {0, 0, -10}, 1)
	far_area := lod_screen_pixels(camera, 1000, {0, 0, -20}, 1)
	testing.expectf(t, abs(near_area - math.PI / 4 * 100 * 100) <= 0.01, "near area %v", near_area)
	testing.expectf(t, abs(far_area * 4 - near_area) <= 0.01, "far area %v, near area %v", far_area, near_area)
	testing.expect_value(t, lod_screen_pixels(camera, 1000, {0, 0, -0.5}, 1), 1000 * 1000)
}
