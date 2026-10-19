#+build !js
package engine

import "core:math"
import "core:math/linalg"
import "core:testing"

@(private = "file")
expect_near :: proc(t: ^testing.T, got, expected: f32, tolerance: f32 = 1e-5, location := #caller_location) {
	testing.expectf(t, abs(got - expected) <= tolerance, "expected %v, got %v", expected, got, loc = location)
}

@(test)
test_view_matrix_puts_the_target_on_the_view_axis :: proc(t: ^testing.T) {
	camera := Camera {
		position = {0, 0, 5},
		target = {0, 0, 0},
		up = {0, 1, 0},
		vertical_fov_radians = math.PI / 2,
		near = 0.1,
		far = 100,
	}
	origin := view_matrix(camera) * [4]f32{0, 0, 0, 1}
	expect_near(t, origin.x, 0)
	expect_near(t, origin.y, 0)
	expect_near(t, origin.z, -5)
	expect_near(t, origin.w, 1)
}

@(test)
test_projection_maps_near_and_far_to_the_clip_range :: proc(t: ^testing.T) {
	camera := Camera {
		vertical_fov_radians = math.PI / 2,
		near = 0.1,
		far = 100,
	}
	projection := projection_matrix(camera, 1)
	near_point := projection * [4]f32{0, 0, -0.1, 1}
	far_point := projection * [4]f32{0, 0, -100, 1}
	expect_near(t, near_point.z / near_point.w, -1)
	expect_near(t, far_point.z / far_point.w, 1)
}

@(test)
test_world_to_screen_centre_and_behind :: proc(t: ^testing.T) {
	camera := Camera {
		position = {0, 0, 5},
		target = {0, 0, 0},
		up = {0, 1, 0},
		vertical_fov_radians = math.PI / 2,
		near = 0.1,
		far = 100,
	}
	pixel, visible := world_to_screen(camera, 4.0 / 3.0, {800, 600}, {0, 0, 0})
	testing.expect(t, visible)
	expect_near(t, pixel.x, 400, 1e-3)
	expect_near(t, pixel.y, 300, 1e-3)
	above, _ := world_to_screen(camera, 4.0 / 3.0, {800, 600}, {0, 1, 0})
	testing.expect(t, above.y < 300)
	_, behind_visible := world_to_screen(camera, 4.0 / 3.0, {800, 600}, {0, 0, 10})
	testing.expect(t, !behind_visible)
}

@(test)
test_orbit_camera_sits_behind_the_target_at_yaw_zero :: proc(t: ^testing.T) {
	camera := orbit_camera(Orbit{distance = 5}, math.PI / 2, 0.1, 100)
	expect_near(t, camera.position.x, 0)
	expect_near(t, camera.position.y, 0)
	expect_near(t, camera.position.z, 5)
	testing.expect_value(t, camera.up, [3]f32{0, 1, 0})
}

@(test)
test_orbit_camera_rises_with_pitch :: proc(t: ^testing.T) {
	camera := orbit_camera(Orbit{pitch = math.PI / 4, distance = 5}, math.PI / 2, 0.1, 100)
	expected := 5 * math.sqrt(f32(2)) / 2
	expect_near(t, camera.position.x, 0)
	expect_near(t, camera.position.y, expected)
	expect_near(t, camera.position.z, expected)
}

@(test)
test_orbit_fit_width :: proc(t: ^testing.T) {
	orbit := Orbit{distance = 7.5}
	expect_near(t, orbit_fit_width(orbit, 10, math.PI / 3, 0.5, 40).distance, 10 * math.sqrt(f32(3)), 1e-4)
	testing.expect_value(t, orbit_fit_width(orbit, 10, math.PI / 3, 2, 40).distance, 7.5)
	testing.expect_value(t, orbit_fit_width(orbit, 10, math.PI / 3, 0.5, 12).distance, 12)
	testing.expect_value(t, orbit_fit_width(orbit, 0, math.PI / 3, 0.5, 40), orbit)
}

@(test)
test_fly_from_orbit_looks_at_the_target :: proc(t: ^testing.T) {
	orbit := Orbit{target = {1, 2, 3}, yaw = 0.7, pitch = 0.4, distance = 5}
	orbit_position := orbit_camera(orbit, 0, 0, 0).position
	fly := fly_from_orbit(orbit)
	expect_near(t, fly.position.x, orbit_position.x, 1e-4)
	expect_near(t, fly.position.y, orbit_position.y, 1e-4)
	expect_near(t, fly.position.z, orbit_position.z, 1e-4)
	camera := fly_camera(fly, math.PI / 3, 0.1, 100)
	expected := fly.position + (orbit.target - fly.position) / orbit.distance
	expect_near(t, camera.target.x, expected.x, 1e-4)
	expect_near(t, camera.target.y, expected.y, 1e-4)
	expect_near(t, camera.target.z, expected.z, 1e-4)
}

@(test)
test_fly_turn_turns_and_clamps :: proc(t: ^testing.T) {
	fly := Fly{yaw = 0, pitch = 0}
	turned := fly_turn(fly, {10, 10}, 0.01)
	expect_near(t, turned.yaw, -0.1)
	expect_near(t, turned.pitch, 0.1)
	expect_near(t, fly_turn(fly, {0, 1000}, 0.01).pitch, ORBIT_PITCH_LIMIT)
	expect_near(t, fly_turn(fly, {0, -1000}, 0.01).pitch, -ORBIT_PITCH_LIMIT)
}

@(test)
test_orbit_turn_turns_and_clamps :: proc(t: ^testing.T) {
	orbit := Orbit{yaw = 0, pitch = 0, distance = 5}
	turned := orbit_turn(orbit, {10, 10}, 0.01)
	expect_near(t, turned.yaw, -0.1)
	expect_near(t, turned.pitch, 0.1)
	expect_near(t, turned.distance, 5)
	expect_near(t, orbit_turn(orbit, {0, 1000}, 0.01).pitch, ORBIT_PITCH_LIMIT)
	expect_near(t, orbit_turn(orbit, {0, -1000}, 0.01).pitch, -ORBIT_PITCH_LIMIT)
}

@(test)
test_orbit_zoom_scales_and_clamps :: proc(t: ^testing.T) {
	orbit := Orbit{distance = 4}
	expect_near(t, orbit_zoom(orbit, math.ln(f32(2)), 1, 30).distance, 2)
	expect_near(t, orbit_zoom(orbit, -math.ln(f32(2)), 1, 30).distance, 8)
	expect_near(t, orbit_zoom(orbit, 10, 1, 30).distance, 1)
	expect_near(t, orbit_zoom(orbit, -10, 1, 30).distance, 30)
}

@(test)
test_fly_walk_moves_along_the_ground_and_up :: proc(t: ^testing.T) {
	fly := Fly{yaw = 0, pitch = 0.5}
	forward := fly_walk(fly, {0, 0, 1}, 1).position
	expect_near(t, forward.x, 0)
	expect_near(t, forward.y, 0)
	expect_near(t, forward.z, -1)
	right := fly_walk(fly, {1, 0, 0}, 1).position
	expect_near(t, right.x, 1)
	expect_near(t, right.y, 0)
	expect_near(t, right.z, 0)
	up := fly_walk(fly, {0, 1, 0}, 1).position
	expect_near(t, up.x, 0)
	expect_near(t, up.y, 1)
	expect_near(t, up.z, 0)
}

@(test)
test_stick_dead_zone :: proc(t: ^testing.T) {
	testing.expect(t, stick_dead_zone(0.1, 0.15) == 0)
	testing.expect(t, math.abs(stick_dead_zone(1, 0.15) - 1) < 1e-5)
	testing.expect(t, math.abs(stick_dead_zone(0.575, 0.15) - 0.5) < 1e-5)
	testing.expect(t, math.abs(stick_dead_zone(-0.575, 0.15) + 0.5) < 1e-5)
}

@(test)
test_box_mesh_has_six_faces :: proc(t: ^testing.T) {
	mesh := box_mesh({2, 2, 2})
	defer mesh_data_destroy(&mesh)
	testing.expect_value(t, len(mesh.vertices), 24)
	testing.expect_value(t, len(mesh.indices), 36)
	direction_counts: map[[3]f32]int
	defer delete(direction_counts)
	for vertex in mesh.vertices {
		for component in vertex.position {
			testing.expect(t, component == 1 || component == -1)
		}
		unit_components, zero_components := 0, 0
		for component in vertex.normal {
			if component == 1 || component == -1 do unit_components += 1
			if component == 0 do zero_components += 1
		}
		testing.expect_value(t, unit_components, 1)
		testing.expect_value(t, zero_components, 2)
		direction_counts[vertex.normal] += 1
	}
	testing.expect_value(t, len(direction_counts), 6)
	for _, count in direction_counts {
		testing.expect_value(t, count, 4)
	}
	for index in mesh.indices {
		testing.expect(t, index < 24)
	}
}

@(test)
test_room_mesh_faces_inward :: proc(t: ^testing.T) {
	mesh := room_mesh({2, 2, 2})
	defer mesh_data_destroy(&mesh)
	testing.expect_value(t, len(mesh.vertices), 24)
	testing.expect_value(t, len(mesh.indices), 36)
	for vertex in mesh.vertices {
		testing.expect(t, linalg.dot(vertex.normal, vertex.position) < 0)
	}
	for index := 0; index < len(mesh.indices); index += 3 {
		a := mesh.vertices[mesh.indices[index]]
		b := mesh.vertices[mesh.indices[index + 1]]
		c := mesh.vertices[mesh.indices[index + 2]]
		winding := linalg.cross(b.position - a.position, c.position - a.position)
		testing.expect(t, linalg.dot(winding, a.normal) > 0)
	}
}

@(test)
test_cylinder_mesh_counts_and_normals :: proc(t: ^testing.T) {
	segments :: 8
	mesh := cylinder_mesh(1, 2, segments)
	defer mesh_data_destroy(&mesh)
	testing.expect_value(t, len(mesh.vertices), 36)
	testing.expect_value(t, len(mesh.indices), 96)
	side_vertex_count := 2 * (segments + 1)
	for vertex, vertex_index in mesh.vertices {
		normal := vertex.normal
		expect_near(t, math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z), 1)
		if vertex_index < side_vertex_count {
			testing.expect_value(t, normal.y, 0)
		}
	}
	for index in mesh.indices {
		testing.expect(t, index < 36)
	}
}

@(test)
test_draw_list_add_and_clear :: proc(t: ^testing.T) {
	list: Draw_List
	defer draw_list_destroy(&list)
	draw_list_add(&list, 1, 2, 1, {1, 1, 1})
	draw_list_add(&list, 3, 4, 1, {1, 1, 1})
	testing.expect_value(t, len(list.items), 2)
	draw_list_clear(&list)
	testing.expect_value(t, len(list.items), 0)
}

@(test)
test_draw_list_lights_add_and_clear :: proc(t: ^testing.T) {
	list: Draw_List
	defer draw_list_destroy(&list)
	draw_list_add(&list, 1, 2, 1, {1, 1, 1})
	draw_list_add_light(&list, Point_Light{position = {1, 2, 3}, colour = {1, 0, 0}, intensity = 2, range = 4})
	draw_list_add_light(&list, Point_Light{position = {-1, 0, 1}, colour = {0, 0, 1}, intensity = 1, range = 3})
	testing.expect_value(t, len(list.lights), 2)
	draw_list_clear(&list)
	testing.expect_value(t, len(list.items), 0)
	testing.expect_value(t, len(list.lights), 0)
}
