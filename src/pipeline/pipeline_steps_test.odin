#+build !js
package pipeline

import "core:strings"
import "core:testing"

// Two unit quads side by side in the y = 0 plane, each its own piece of
// two triangles: piece_a over x 0 to 1, piece_b over x 2 to 3.
two_quads :: proc() -> Pipeline_Mesh {
	mesh: Pipeline_Mesh
	for offset, piece in ([]f32{0, 2}) {
		base := u32(len(mesh.positions))
		append(&mesh.positions, [3]f32{offset, 0, 0}, [3]f32{offset + 1, 0, 0}, [3]f32{offset + 1, 0, 1}, [3]f32{offset, 0, 1})
		append(&mesh.normals, [3]f32{0, 1, 0}, [3]f32{0, 1, 0}, [3]f32{0, 1, 0}, [3]f32{0, 1, 0})
		append(&mesh.triangles, [3]u32{base, base + 1, base + 2}, [3]u32{base, base + 2, base + 3})
		append(&mesh.pieces, u32(piece), u32(piece))
		append(&mesh.parts, PART_NONE, PART_NONE)
	}
	append(&mesh.piece_names, strings.clone("piece_a"), strings.clone("piece_b"))
	return mesh
}

expect_near :: proc(t: ^testing.T, value, expected: [3]f32, loc := #caller_location) {
	difference := value - expected
	near := abs(difference.x) < 1e-5 && abs(difference.y) < 1e-5 && abs(difference.z) < 1e-5
	testing.expectf(t, near, "got %v, expected %v", value, expected, loc = loc)
}

count_true :: proc(flags: []bool) -> int {
	count := 0
	for flag in flags {
		if flag {
			count += 1
		}
	}
	return count
}

@(test)
test_transform_turns_grounds_and_scales :: proc(t: ^testing.T) {
	mesh: Pipeline_Mesh
	defer pipeline_mesh_destroy(&mesh)
	append(&mesh.positions, [3]f32{2, 1, 0}, [3]f32{4, 3, 2}, [3]f32{2, 1, 2})
	append(&mesh.normals, [3]f32{1, 0, 0}, [3]f32{1, 0, 0}, [3]f32{1, 0, 0})
	append(&mesh.triangles, [3]u32{0, 1, 2})
	step_transform(&mesh, .Plus_X, 4)
	// Bottom centre (3, 1, 1), factor 2, then (x, y, z) becomes (-z, y, x).
	expect_near(t, mesh.positions[0], {2, 0, -2})
	expect_near(t, mesh.positions[1], {-2, 4, 2})
	expect_near(t, mesh.positions[2], {-2, 0, -2})
	expect_near(t, mesh.normals[0], {0, 0, 1})
}

@(test)
test_weld_merges_close_vertices_and_drops_degenerate_triangles :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	// A sliver triangle whose corners all fall in one cell of the first vertex.
	base := u32(len(mesh.positions))
	append(&mesh.positions, [3]f32{0.01, 0.01, 0.01}, [3]f32{0.02, 0.01, 0.01}, [3]f32{0.01, 0.02, 0.01})
	append(&mesh.normals, [3]f32{0, 1, 0}, [3]f32{0, 1, 0}, [3]f32{0, 1, 0})
	append(&mesh.triangles, [3]u32{base, base + 1, base + 2})
	append(&mesh.pieces, 0)
	append(&mesh.parts, PART_NONE)
	step_weld(&mesh, 0.5)
	testing.expect_value(t, len(mesh.triangles), 4)
	testing.expect_value(t, len(mesh.pieces), 4)
	testing.expect_value(t, len(mesh.parts), 4)
	testing.expect_value(t, len(mesh.positions), 8)
	testing.expect_value(t, len(mesh.normals), 8)
	expect_near(t, mesh.positions[mesh.triangles[0][0]], {0, 0, 0})
}

@(test)
test_select_by_each_kind :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	mesh.parts[3] = 0
	append(&mesh.part_names, strings.clone("body"))
	pieces := []string{"piece_b"}
	strokes := []Stroke{{position = {0.33, 0, 0.67}, radius = 0.1}}
	cases := []struct {
		select:   Select,
		expected: [4]bool,
	} {
		{{kind = .Pieces, pieces = pieces}, {false, false, true, true}},
		{{kind = .Part, part = "body"}, {false, false, false, true}},
		{{kind = .Box, minimum = {0, -1, 0}, maximum = {1, 1, 1}}, {true, true, false, false}},
		{{kind = .Sphere, centre = {2.67, 0, 0.33}, radius = 0.1}, {false, false, true, false}},
		{{kind = .Strokes, strokes = strokes}, {false, true, false, false}},
	}
	for test_case in cases {
		selected := select_triangles(mesh, test_case.select)
		defer delete(selected)
		for expected, index in test_case.expected {
			testing.expectf(t, selected[index] == expected, "%v triangle %d", test_case.select.kind, index)
		}
	}
}

@(test)
test_select_within_part_narrows :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	mesh.parts[1] = 0
	mesh.parts[2] = 0
	append(&mesh.part_names, strings.clone("body"))
	selected := select_triangles(mesh, {kind = .Pieces, pieces = []string{"piece_a"}, within_part = "body"})
	defer delete(selected)
	testing.expect_value(t, count_true(selected), 1)
	testing.expect(t, selected[1])
}

@(test)
test_assign_sets_the_part :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	step_assign(&mesh, "body", []bool{true, false, false, true})
	step_assign(&mesh, "body", []bool{false, true, false, false})
	testing.expect_value(t, len(mesh.part_names), 1)
	testing.expect_value(t, mesh.parts[0], 0)
	testing.expect_value(t, mesh.parts[1], 0)
	testing.expect_value(t, mesh.parts[2], PART_NONE)
	testing.expect_value(t, mesh.parts[3], 0)
	index, found := pipeline_mesh_part_index(&mesh, "body")
	testing.expect(t, found)
	testing.expect_value(t, index, 0)
	_, missing_found := pipeline_mesh_part_index(&mesh, "missing")
	testing.expect(t, !missing_found)
	testing.expect_value(t, len(mesh.part_names), 1)
}

@(test)
test_delete_compacts :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	mesh.parts[3] = 7
	step_delete(&mesh, []bool{true, true, true, false})
	testing.expect_value(t, len(mesh.triangles), 1)
	testing.expect_value(t, mesh.pieces[0], 1)
	testing.expect_value(t, mesh.parts[0], 7)
	testing.expect_value(t, len(mesh.positions), 3)
	testing.expect_value(t, len(mesh.normals), 3)
	testing.expect_value(t, mesh.triangles[0], [3]u32{0, 1, 2})
	expect_near(t, mesh.positions[0], {2, 0, 0})
	expect_near(t, mesh.positions[1], {3, 0, 1})
	expect_near(t, mesh.positions[2], {2, 0, 1})
}

@(test)
test_copy_turns_and_moves_into_a_new_piece :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	mesh.normals[0] = {1, 0, 0}
	mesh.parts[0] = 0
	append(&mesh.part_names, strings.clone("body"))
	step_copy(&mesh, []bool{true, true, false, false}, {0, 0, 0}, {10, 0, 0}, 1)
	testing.expect_value(t, len(mesh.triangles), 6)
	testing.expect_value(t, len(mesh.positions), 12)
	testing.expect_value(t, len(mesh.piece_names), 3)
	testing.expect_value(t, mesh.piece_names[2], "copy_1")
	testing.expect_value(t, mesh.pieces[4], 2)
	testing.expect_value(t, mesh.pieces[5], 2)
	testing.expect_value(t, mesh.parts[4], 0)
	testing.expect_value(t, mesh.parts[5], PART_NONE)
	// One quarter turn takes +x to -z, then the copy moves by 10 along x.
	copied := mesh.triangles[4]
	expect_near(t, mesh.positions[copied[1]], {10, 0, -1})
	expect_near(t, mesh.positions[copied[2]], {11, 0, -1})
	expect_near(t, mesh.normals[copied[0]], {0, 0, -1})
	step_copy(&mesh, []bool{true, false, false, false, false, false}, {}, {}, 0)
	testing.expect_value(t, mesh.piece_names[3], "copy_2")
}

@(test)
test_stroke_counts :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	strokes := []Stroke{{position = {0.5, 0, 0.5}, radius = 0.5}, {position = {2.67, 0, 0.33}, radius = 0.1}, {position = {9, 9, 9}, radius = 1}}
	counts := stroke_triangle_counts(mesh, strokes)
	defer delete(counts)
	testing.expect_value(t, counts[0], 2)
	testing.expect_value(t, counts[1], 1)
	testing.expect_value(t, counts[2], 0)
}
