package engine

import "core:math"
import "core:math/linalg"

// The dials of the level of detail choice: the screen pixels a triangle must
// cover, the hysteresis band as a fraction of the screen pixels, the seconds a
// switch takes to fade, and the freeze and tint switches of the demo.
Lod_Settings :: struct {
	pixels_per_triangle, hysteresis, crossfade_seconds: f32,
	freeze, tint:                                       bool,
}

LOD_SETTINGS_DEFAULT :: Lod_Settings {
	pixels_per_triangle = 8,
	hysteresis          = 0.15,
	crossfade_seconds   = 0.4,
}

// The finest level whose triangles each cover pixels_per_triangle of the
// screen pixels, the coarsest when none does. The counts run finest first.
lod_wanted :: proc(triangle_counts: []int, screen_pixels, pixels_per_triangle: f32) -> int {
	for count, index in triangle_counts {
		if f32(count) * pixels_per_triangle <= screen_pixels do return index
	}
	return len(triangle_counts) - 1
}

// The current level unless the wanted level stays on the same side of it
// with the screen pixels moved by the hysteresis fraction against the switch.
lod_choose :: proc(current: int, triangle_counts: []int, screen_pixels, pixels_per_triangle, hysteresis: f32) -> int {
	held := clamp(current, 0, len(triangle_counts) - 1)
	finer := lod_wanted(triangle_counts, screen_pixels * (1 - hysteresis), pixels_per_triangle)
	if finer < held do return finer
	coarser := lod_wanted(triangle_counts, screen_pixels * (1 + hysteresis), pixels_per_triangle)
	if coarser > held do return coarser
	return held
}

// The area in canvas pixels of a bounding sphere's projected disc, the canvas
// height squared when the camera is inside the sphere.
lod_screen_pixels :: proc(camera: Camera, canvas_height: f32, centre: [3]f32, radius: f32) -> f32 {
	distance := linalg.length(centre - camera.position)
	if distance <= radius do return canvas_height * canvas_height
	diameter := radius / (distance * math.tan(camera.vertical_fov_radians / 2)) * canvas_height
	return math.PI / 4 * diameter * diameter
}

// The debug colour of a level, eight distinct ones finest first, the last for every level past them.
lod_tint :: proc(level: int) -> [3]f32 {
	palette := [8][3]f32{{1, 1, 1}, {0.2, 0.9, 0.2}, {0.2, 0.5, 1}, {1, 0.9, 0.1}, {1, 0.5, 0.1}, {0.9, 0.2, 0.9}, {0.1, 0.9, 0.9}, {1, 0.15, 0.15}}
	return palette[clamp(level, 0, len(palette) - 1)]
}
