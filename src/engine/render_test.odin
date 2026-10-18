#+build !js
package engine

import "core:math"
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
test_orbit_drag_turns_and_clamps :: proc(t: ^testing.T) {
	turned := orbit_drag(Orbit{distance = 5}, {100, 0}, 0.01)
	expect_near(t, turned.yaw, -1)
	expect_near(t, turned.pitch, 0)
	raised := orbit_drag(Orbit{distance = 5}, {0, 1000}, 0.01)
	testing.expect_value(t, raised.pitch, ORBIT_PITCH_LIMIT)
}

@(test)
test_orbit_zoom_scales_and_clamps :: proc(t: ^testing.T) {
	testing.expect_value(t, orbit_zoom(Orbit{distance = 5}, 2, 2, 20).distance, 10)
	testing.expect_value(t, orbit_zoom(Orbit{distance = 15}, 2, 2, 20).distance, 20)
}

@(test)
test_orbit_pan_moves_the_target_in_the_view_plane :: proc(t: ^testing.T) {
	orbit := Orbit{distance = 5}
	sideways := orbit_pan(orbit, {10, 0}, 0.1).target
	testing.expect(t, math.abs(sideways.x - -1) < 1e-5)
	testing.expect(t, math.abs(sideways.y) < 1e-5)
	testing.expect(t, math.abs(sideways.z) < 1e-5)
	upwards := orbit_pan(orbit, {0, 10}, 0.1).target
	testing.expect(t, math.abs(upwards.x) < 1e-5)
	testing.expect(t, math.abs(upwards.y - 1) < 1e-5)
	testing.expect(t, math.abs(upwards.z) < 1e-5)
}

@(test)
test_orbit_metres_per_pixel :: proc(t: ^testing.T) {
	metres_per_pixel := orbit_metres_per_pixel(Orbit{distance = 5}, math.PI / 2, 1000)
	testing.expect(t, math.abs(metres_per_pixel - 0.01) < 1e-5)
}

@(test)
test_orbit_walk_moves_along_the_ground :: proc(t: ^testing.T) {
	orbit := Orbit{yaw = 0, pitch = 0.5, distance = 5}
	forward := orbit_walk(orbit, {0, 0, 1}, 1)
	testing.expect(t, math.abs(forward.target.x) < 1e-5)
	testing.expect(t, math.abs(forward.target.y) < 1e-5)
	testing.expect(t, math.abs(forward.target.z + 1) < 1e-5)
	right := orbit_walk(orbit, {1, 0, 0}, 1)
	testing.expect(t, math.abs(right.target.x - 1) < 1e-5)
	testing.expect(t, math.abs(right.target.y) < 1e-5)
	testing.expect(t, math.abs(right.target.z) < 1e-5)
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
	draw_list_add(&list, 1, 2, 1)
	draw_list_add(&list, 3, 4, 1)
	testing.expect_value(t, len(list.items), 2)
	draw_list_clear(&list)
	testing.expect_value(t, len(list.items), 0)
}

@(test)
test_draw_list_lights_add_and_clear :: proc(t: ^testing.T) {
	list: Draw_List
	defer draw_list_destroy(&list)
	draw_list_add(&list, 1, 2, 1)
	draw_list_add_light(&list, Point_Light{position = {1, 2, 3}, colour = {1, 0, 0}, intensity = 2, range = 4})
	draw_list_add_light(&list, Point_Light{position = {-1, 0, 1}, colour = {0, 0, 1}, intensity = 1, range = 3})
	testing.expect_value(t, len(list.lights), 2)
	draw_list_clear(&list)
	testing.expect_value(t, len(list.items), 0)
	testing.expect_value(t, len(list.lights), 0)
}
