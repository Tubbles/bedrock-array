#+build !js
package engine

import "core:math"
import "core:testing"

@(test)
test_touch_turn_drags_the_scene :: proc(t: ^testing.T) {
	right := touch_turn({10, 0}, 0.01)
	testing.expect(t, right.x < 0)
	testing.expect(t, fly_turn(Fly{}, right, 1).yaw > 0)
	down := touch_turn({0, 10}, 0.01)
	testing.expect(t, down.y < 0)
}

@(test)
test_touch_pair_move_spread_walks_forward :: proc(t: ^testing.T) {
	metres_per_pixel := f32(0.02)
	move := touch_pair_move({{50, 0}, {150, 0}}, {{0, 0}, {200, 0}}, metres_per_pixel)
	testing.expect(t, math.abs(move.z - 100 * metres_per_pixel) < 1e-5)
	testing.expect(t, math.abs(move.x) < 1e-5)
	testing.expect(t, math.abs(move.y) < 1e-5)
}

@(test)
test_touch_pair_move_drag_moves_with_the_scene :: proc(t: ^testing.T) {
	move := touch_pair_move({{0, 0}, {100, 0}}, {{50, 50}, {150, 50}}, 0.02)
	testing.expect(t, move.x < 0)
	testing.expect(t, move.y > 0)
	testing.expect(t, math.abs(move.z) < 1e-5)
}
