package engine

import "core:math/linalg"

// A finger drags the scene, so a drag right looks left and a drag down looks up, the mouse's opposite. The result goes to fly_turn at one radian per unit.
touch_turn :: proc(movement: [2]f32, radians_per_pixel: f32) -> [2]f32 {
	return -movement * radians_per_pixel
}

// The change of two fingers' distance in pixels, positive when they spread.
touch_pair_spread :: proc(previous, current: [2][2]f32) -> f32 {
	return linalg.distance(current[0], current[1]) - linalg.distance(previous[0], previous[1])
}

// Two fingers in client pixels (y down) to a move in the fly's frame: spreading walks forward and pinching back, dragging both moves the fly with the scene (right goes left, down goes up).
touch_pair_move :: proc(previous, current: [2][2]f32, metres_per_pixel: f32) -> [3]f32 {
	spread := touch_pair_spread(previous, current)
	midpoint := (current[0] + current[1]) / 2 - (previous[0] + previous[1]) / 2
	return [3]f32{-midpoint.x, midpoint.y, spread} * metres_per_pixel
}
