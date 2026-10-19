#+build !js
package engine

import "core:encoding/endian"
import "core:strings"
import "core:testing"

@(private = "file")
TEST_TRIANGLE_VERTICES := [3]Vertex {
	{position = {0, 0, 0}, normal = {0, 0, 1}},
	{position = {2, 0, 0}, normal = {0, 0, 1}},
	{position = {0, 1, -4}, normal = {0, 1, 0}},
}

@(private = "file")
TEST_TRIANGLE_INDICES := [3]u32{0, 1, 2}

// The blob of the given vertices and indices, built byte by byte as the format says.
@(private = "file")
test_mesh_blob :: proc(vertices: []Vertex, indices: []u32, allocator := context.allocator) -> []byte {
	data := make([]byte, 16 + 24 * len(vertices) + 4 * len(indices), allocator)
	copy(data, MESH_BLOB_MAGIC)
	endian.unchecked_put_u32le(data[8:], u32(len(vertices)))
	endian.unchecked_put_u32le(data[12:], u32(len(indices)))
	offset := 16
	for vertex in vertices {
		floats := [6]f32{vertex.position.x, vertex.position.y, vertex.position.z, vertex.normal.x, vertex.normal.y, vertex.normal.z}
		for value in floats {
			endian.unchecked_put_u32le(data[offset:], transmute(u32)value)
			offset += 4
		}
	}
	for value in indices {
		endian.unchecked_put_u32le(data[offset:], value)
		offset += 4
	}
	return data
}

@(test)
test_parse_mesh_blob_reads_a_triangle :: proc(t: ^testing.T) {
	data := test_mesh_blob(TEST_TRIANGLE_VERTICES[:], TEST_TRIANGLE_INDICES[:])
	defer delete(data)
	mesh, problem := parse_mesh_blob(data)
	defer mesh_data_destroy(&mesh)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(mesh.vertices), 3)
	testing.expect_value(t, len(mesh.indices), 3)
	if len(mesh.vertices) == 3 && len(mesh.indices) == 3 {
		for index in 0 ..< 3 {
			testing.expect_value(t, mesh.vertices[index], TEST_TRIANGLE_VERTICES[index])
			testing.expect_value(t, mesh.indices[index], TEST_TRIANGLE_INDICES[index])
		}
	}
}

@(test)
test_parse_mesh_blob_rejects_a_bad_magic_and_a_short_file :: proc(t: ^testing.T) {
	data := test_mesh_blob(TEST_TRIANGLE_VERTICES[:], TEST_TRIANGLE_INDICES[:])
	defer delete(data)
	_, short_problem := parse_mesh_blob(data[:len(data) - 1])
	testing.expectf(t, strings.contains(short_problem, "need"), "problem: %q", short_problem)
	_, header_problem := parse_mesh_blob(data[:4])
	testing.expectf(t, strings.contains(header_problem, "does not start with"), "problem: %q", header_problem)
	data[0] = 'X'
	_, magic_problem := parse_mesh_blob(data)
	testing.expectf(t, strings.contains(magic_problem, "does not start with"), "problem: %q", magic_problem)
	data[0] = 'B'
	bad_indices := [3]u32{0, 1, 3}
	bad_index_data := test_mesh_blob(TEST_TRIANGLE_VERTICES[:], bad_indices[:])
	defer delete(bad_index_data)
	_, index_problem := parse_mesh_blob(bad_index_data)
	testing.expectf(t, strings.contains(index_problem, "at or past"), "problem: %q", index_problem)
}

@(test)
test_mesh_half_extents :: proc(t: ^testing.T) {
	mesh := Mesh_Data{vertices = TEST_TRIANGLE_VERTICES[:], indices = TEST_TRIANGLE_INDICES[:]}
	testing.expect_value(t, mesh_half_extents(mesh), [3]f32{2, 1, 4})
	testing.expect_value(t, scene_item_half_extents(Scene_Item{shape = .Mesh, scale = 2}, mesh), [3]f32{2, 1, 4})
}
