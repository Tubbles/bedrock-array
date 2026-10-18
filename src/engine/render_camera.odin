package engine

import "core:math"
import "core:math/linalg"

// A perspective camera. Metres, y up, right handed.
Camera :: struct {
	position, target, up:            [3]f32,
	vertical_fov_radians, near, far: f32,
}

// A camera position around a target: yaw about y from +z, pitch up from
// the xz plane.
Orbit :: struct {
	target:               [3]f32,
	yaw, pitch, distance: f32,
}

orbit_camera :: proc(orbit: Orbit, vertical_fov_radians, near, far: f32) -> Camera {
	direction := [3]f32 {
		math.cos(orbit.pitch) * math.sin(orbit.yaw),
		math.sin(orbit.pitch),
		math.cos(orbit.pitch) * math.cos(orbit.yaw),
	}
	return Camera {
		position = orbit.target + orbit.distance * direction,
		target = orbit.target,
		up = {0, 1, 0},
		vertical_fov_radians = vertical_fov_radians,
		near = near,
		far = far,
	}
}

// Radians of pitch either way, short of the poles where the up vector fails.
ORBIT_PITCH_LIMIT :: f32(1.5)

// A drag turns the orbit: right lowers yaw, down raises pitch, pitch limited.
orbit_drag :: proc(orbit: Orbit, delta_pixels: [2]f32, radians_per_pixel: f32) -> Orbit {
	result := orbit
	result.yaw -= delta_pixels.x * radians_per_pixel
	result.pitch = clamp(orbit.pitch + delta_pixels.y * radians_per_pixel, -ORBIT_PITCH_LIMIT, ORBIT_PITCH_LIMIT)
	return result
}

// A zoom scales the distance by a factor, kept within minimum and maximum.
orbit_zoom :: proc(orbit: Orbit, factor: f32, minimum, maximum: f32) -> Orbit {
	result := orbit
	result.distance = clamp(orbit.distance * factor, minimum, maximum)
	return result
}

view_matrix :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at_f32(camera.position, camera.target, camera.up)
}

// OpenGL clip space: near maps to -1, far to 1.
projection_matrix :: proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32 {
	return linalg.matrix4_perspective_f32(camera.vertical_fov_radians, aspect, camera.near, camera.far)
}
