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

// A fit moves the camera back until fit_width metres span the canvas at the
// target's depth, never closer than the orbit and never past the maximum.
// A width of 0 leaves the orbit.
orbit_fit_width :: proc(orbit: Orbit, fit_width, vertical_fov_radians, aspect, maximum_distance: f32) -> Orbit {
	if fit_width <= 0 {
		return orbit
	}
	needed := fit_width / (2 * math.tan(vertical_fov_radians / 2) * aspect)
	result := orbit
	result.distance = max(orbit.distance, min(needed, maximum_distance))
	return result
}

// A first person camera. It looks the opposite way of the orbit's offset, so
// an orbit's yaw and pitch carry over and a positive pitch looks down.
Fly :: struct {
	position:   [3]f32,
	yaw, pitch: f32,
}

@(private = "file")
fly_forward :: proc(yaw, pitch: f32) -> [3]f32 {
	return -[3]f32{math.cos(pitch) * math.sin(yaw), math.sin(pitch), math.cos(pitch) * math.cos(yaw)}
}

// A fly standing at the orbit camera's position, looking at the orbit's target.
fly_from_orbit :: proc(orbit: Orbit) -> Fly {
	return Fly{position = orbit_camera(orbit, 0, 0, 0).position, yaw = orbit.yaw, pitch = orbit.pitch}
}

fly_camera :: proc(fly: Fly, vertical_fov_radians, near, far: f32) -> Camera {
	return Camera {
		position = fly.position,
		target = fly.position + fly_forward(fly.yaw, fly.pitch),
		up = {0, 1, 0},
		vertical_fov_radians = vertical_fov_radians,
		near = near,
		far = far,
	}
}

// A move turns the fly: right lowers yaw, down raises pitch, pitch limited.
fly_turn :: proc(fly: Fly, delta_pixels: [2]f32, radians_per_pixel: f32) -> Fly {
	result := fly
	result.yaw -= delta_pixels.x * radians_per_pixel
	result.pitch = clamp(fly.pitch + delta_pixels.y * radians_per_pixel, -ORBIT_PITCH_LIMIT, ORBIT_PITCH_LIMIT)
	return result
}

// A walk moves the position: x along the right, y along world up, z along the horizontal forward.
fly_walk :: proc(fly: Fly, input: [3]f32, metres: f32) -> Fly {
	forward := fly_forward(fly.yaw, fly.pitch)
	forward.y = 0
	forward = linalg.normalize(forward)
	right := linalg.cross(forward, [3]f32{0, 1, 0})
	result := fly
	result.position += (input.x * right + input.y * [3]f32{0, 1, 0} + input.z * forward) * metres
	return result
}

// A pan moves the target in the view plane so the world follows the drag.
orbit_pan :: proc(orbit: Orbit, delta_pixels: [2]f32, metres_per_pixel: f32) -> Orbit {
	right, up := orbit_right_and_up(orbit)
	result := orbit
	result.target += (-delta_pixels.x * right + delta_pixels.y * up) * metres_per_pixel
	return result
}

// The width of one pixel at the target's depth.
orbit_metres_per_pixel :: proc(orbit: Orbit, vertical_fov_radians: f32, canvas_height_pixels: f32) -> f32 {
	return 2 * orbit.distance * math.tan(vertical_fov_radians / 2) / canvas_height_pixels
}

// A walk moves the target: x along the right, y along world up, z along the horizontal forward.
orbit_walk :: proc(orbit: Orbit, input: [3]f32, metres: f32) -> Orbit {
	right, _ := orbit_right_and_up(orbit)
	camera := orbit_camera(orbit, 0, 0, 0)
	forward := camera.target - camera.position
	forward.y = 0
	forward = linalg.normalize(forward)
	result := orbit
	result.target += (input.x * right + input.y * [3]f32{0, 1, 0} + input.z * forward) * metres
	return result
}

// A stick axis with its dead zone removed: 0 inside it, the rest rescaled to 0..1 with the sign kept.
stick_dead_zone :: proc(value, dead: f32) -> f32 {
	if math.abs(value) <= dead do return 0
	return math.sign(value) * (math.abs(value) - dead) / (1 - dead)
}

@(private = "file")
orbit_right_and_up :: proc(orbit: Orbit) -> (right, up: [3]f32) {
	camera := orbit_camera(orbit, 0, 0, 0)
	forward := linalg.normalize(camera.target - camera.position)
	right = linalg.normalize(linalg.cross(forward, [3]f32{0, 1, 0}))
	up = linalg.cross(right, forward)
	return right, up
}

view_matrix :: proc(camera: Camera) -> matrix[4, 4]f32 {
	return linalg.matrix4_look_at_f32(camera.position, camera.target, camera.up)
}

// OpenGL clip space: near maps to -1, far to 1.
projection_matrix :: proc(camera: Camera, aspect: f32) -> matrix[4, 4]f32 {
	return linalg.matrix4_perspective_f32(camera.vertical_fov_radians, aspect, camera.near, camera.far)
}

// The canvas pixel of a world point, from the top left with y down, and
// whether it lies in front of the camera within the view.
world_to_screen :: proc(camera: Camera, aspect: f32, canvas: [2]f32, world: [3]f32) -> (pixel: [2]f32, visible: bool) {
	clip := projection_matrix(camera, aspect) * view_matrix(camera) * [4]f32{world.x, world.y, world.z, 1}
	if clip.w <= 0 do return {}, false
	normalised := clip.xy / clip.w
	pixel = {(normalised.x + 1) / 2 * canvas.x, (1 - normalised.y) / 2 * canvas.y}
	visible = abs(normalised.x) <= 1 && abs(normalised.y) <= 1
	return pixel, visible
}
