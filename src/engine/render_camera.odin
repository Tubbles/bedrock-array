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

view_matrix :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at_f32(camera.position, camera.target, camera.up)
}

// OpenGL clip space: near maps to -1, far to 1.
projection_matrix :: proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32 {
	return linalg.matrix4_perspective_f32(camera.vertical_fov_radians, aspect, camera.near, camera.far)
}
