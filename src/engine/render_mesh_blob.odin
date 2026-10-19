package engine

import "core:encoding/endian"
import "core:fmt"

// The blob of doc/workflows/models.md: the magic, a u32 vertex count, a u32
// index count, six f32 per vertex (position, normal), then the u32 indices,
// all little endian.
MESH_BLOB_MAGIC :: "BAMESH01"

@(private = "file")
MESH_BLOB_HEADER_BYTES :: 16
@(private = "file")
MESH_BLOB_VERTEX_BYTES :: 24

// The problem text lives in context.temp_allocator, valid until its next reset.
parse_mesh_blob :: proc(data: []byte, allocator := context.allocator) -> (mesh: Mesh_Data, problem: string) {
	if len(data) < MESH_BLOB_HEADER_BYTES || string(data[:len(MESH_BLOB_MAGIC)]) != MESH_BLOB_MAGIC {
		return {}, "mesh blob: does not start with " + MESH_BLOB_MAGIC
	}
	// In i64, since the counts and their byte sizes overflow a wasm32 int.
	vertex_count_wide := i64(endian.unchecked_get_u32le(data[8:]))
	index_count_wide := i64(endian.unchecked_get_u32le(data[12:]))
	expected_length := MESH_BLOB_HEADER_BYTES + MESH_BLOB_VERTEX_BYTES * vertex_count_wide + 4 * index_count_wide
	if i64(len(data)) != expected_length {
		return {}, fmt.tprintf("mesh blob: %d bytes, %d vertices and %d indices need %d", len(data), vertex_count_wide, index_count_wide, expected_length)
	}
	vertex_count := int(vertex_count_wide)
	index_count := int(index_count_wide)
	index_start := MESH_BLOB_HEADER_BYTES + MESH_BLOB_VERTEX_BYTES * vertex_count
	for index in 0 ..< index_count {
		value := int(endian.unchecked_get_u32le(data[index_start + 4 * index:]))
		if value >= vertex_count {
			return {}, fmt.tprintf("mesh blob: index %d is %d, at or past the %d vertices", index, value, vertex_count)
		}
	}
	mesh.vertices = make([]Vertex, vertex_count, allocator)
	for &vertex, index in mesh.vertices {
		vertex = mesh_blob_vertex(data[MESH_BLOB_HEADER_BYTES + MESH_BLOB_VERTEX_BYTES * index:])
	}
	mesh.indices = make([]u32, index_count, allocator)
	for &value, index in mesh.indices {
		value = endian.unchecked_get_u32le(data[index_start + 4 * index:])
	}
	return mesh, ""
}

// The half extents of the smallest box centred on the origin that holds the
// vertices, the box the shader's edge distance assumes.
mesh_half_extents :: proc(mesh: Mesh_Data) -> [3]f32 {
	half_extents: [3]f32
	for vertex in mesh.vertices {
		half_extents = {
			max(half_extents.x, abs(vertex.position.x)),
			max(half_extents.y, abs(vertex.position.y)),
			max(half_extents.z, abs(vertex.position.z)),
		}
	}
	return half_extents
}

@(private = "file")
mesh_blob_vertex :: proc(data: []byte) -> Vertex {
	floats: [6]f32
	for &value, index in floats {
		value = transmute(f32)endian.unchecked_get_u32le(data[4 * index:])
	}
	return Vertex{position = {floats[0], floats[1], floats[2]}, normal = {floats[3], floats[4], floats[5]}}
}
