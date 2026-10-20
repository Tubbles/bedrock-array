#+build !js
package pipeline

import "core:testing"

@(test)
test_ray_pick :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	position, triangle, hit := ray_pick(mesh, {2.75, 1, 0.25}, {0, -1, 0})
	testing.expect(t, hit)
	testing.expect_value(t, triangle, 2)
	expect_near(t, position, {2.75, 0, 0.25})
	_, _, from_below := ray_pick(mesh, {0.5, -1, 0.5}, {0, 1, 0})
	testing.expect(t, from_below)
	_, _, between := ray_pick(mesh, {1.5, 1, 0.5}, {0, -1, 0})
	testing.expect(t, !between)
	_, _, away := ray_pick(mesh, {0.5, 1, 0.5}, {0, 1, 0})
	testing.expect(t, !away)
}

// The nearer of two stacked triangles is the one picked.
@(test)
test_ray_pick_nearest :: proc(t: ^testing.T) {
	mesh: Pipeline_Mesh
	defer pipeline_mesh_destroy(&mesh)
	append(&mesh.positions, [3]f32{0, 0, 0}, [3]f32{1, 0, 0}, [3]f32{0, 0, 1}, [3]f32{0, 1, 0}, [3]f32{1, 1, 0}, [3]f32{0, 1, 1})
	append(&mesh.triangles, [3]u32{0, 1, 2}, [3]u32{3, 4, 5})
	position, triangle, hit := ray_pick(mesh, {0.2, 5, 0.2}, {0, -1, 0})
	testing.expect(t, hit)
	testing.expect_value(t, triangle, 1)
	testing.expect_value(t, position.y, f32(1))
}
