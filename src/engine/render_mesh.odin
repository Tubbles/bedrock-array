package engine

import "core:math"

Vertex :: struct {
	position, normal: [3]f32,
}

Mesh_Data :: struct {
	vertices: []Vertex,
	indices:  []u32,
}

// The six faces of a box: normal, then the two axes spanning the face,
// ordered so that first cross second is the normal (counter clockwise
// seen from outside).
@(private = "file")
BOX_FACES := [6][3][3]f32 {
	{{1, 0, 0}, {0, 0, -1}, {0, 1, 0}},
	{{-1, 0, 0}, {0, 0, 1}, {0, 1, 0}},
	{{0, 1, 0}, {1, 0, 0}, {0, 0, -1}},
	{{0, -1, 0}, {1, 0, 0}, {0, 0, 1}},
	{{0, 0, 1}, {1, 0, 0}, {0, 1, 0}},
	{{0, 0, -1}, {-1, 0, 0}, {0, 1, 0}},
}

// A box centred at the origin: 24 vertices, 36 indices.
box_mesh :: proc(size: [3]f32, allocator := context.allocator) -> Mesh_Data {
	vertices := make([]Vertex, 24, allocator)
	indices := make([]u32, 36, allocator)
	half := size / 2
	corners := [4][2]f32{{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}
	for face, face_index in BOX_FACES {
		normal, first_axis, second_axis := face[0], face[1], face[2]
		base := face_index * 4
		for corner, corner_index in corners {
			direction := normal + corner[0] * first_axis + corner[1] * second_axis
			vertices[base + corner_index] = Vertex{position = direction * half, normal = normal}
		}
		quad := [6]int{0, 1, 2, 0, 2, 3}
		for offset, index in quad {
			indices[face_index * 6 + index] = u32(base + offset)
		}
	}
	return Mesh_Data{vertices = vertices, indices = indices}
}

// A cylinder along y, centred at the origin: 4 * (segments + 1) vertices,
// 12 * segments indices.
cylinder_mesh :: proc(radius, height: f32, segments: int, allocator := context.allocator) -> Mesh_Data {
	vertices := make([]Vertex, 4 * (segments + 1), allocator)
	indices := make([]u32, 12 * segments, allocator)
	half_height := height / 2
	vertex_count := 0
	index_count := 0
	// The side: a bottom ring and a top ring, the seam vertex repeated.
	for ring in 0 ..< 2 {
		y := ring == 0 ? -half_height : half_height
		for segment in 0 ..= segments {
			normal := ring_direction(segment, segments)
			vertices[vertex_count] = Vertex{position = {normal.x * radius, y, normal.z * radius}, normal = normal}
			vertex_count += 1
		}
	}
	for segment in 0 ..< segments {
		bottom := u32(segment)
		top := u32(segments + 1 + segment)
		quad := [6]u32{bottom, bottom + 1, top + 1, bottom, top + 1, top}
		for value in quad {
			indices[index_count] = value
			index_count += 1
		}
	}
	// The caps: a centre vertex and a ring, fanned with wrap around.
	for cap_index in 0 ..< 2 {
		y := cap_index == 0 ? -half_height : half_height
		normal := [3]f32{0, cap_index == 0 ? -1 : 1, 0}
		centre := u32(vertex_count)
		vertices[vertex_count] = Vertex{position = {0, y, 0}, normal = normal}
		vertex_count += 1
		for segment in 0 ..< segments {
			direction := ring_direction(segment, segments)
			vertices[vertex_count] = Vertex{position = {direction.x * radius, y, direction.z * radius}, normal = normal}
			vertex_count += 1
		}
		for segment in 0 ..< segments {
			current := centre + 1 + u32(segment)
			next := centre + 1 + u32((segment + 1) % segments)
			triangle := cap_index == 0 ? [3]u32{centre, next, current} : [3]u32{centre, current, next}
			for value in triangle {
				indices[index_count] = value
				index_count += 1
			}
		}
	}
	return Mesh_Data{vertices = vertices, indices = indices}
}

// The unit direction in the xz plane of a ring vertex, starting at +z.
@(private = "file")
ring_direction :: proc(segment, segments: int) -> [3]f32 {
	angle := 2 * math.PI * f32(segment) / f32(segments)
	return {math.sin(angle), 0, math.cos(angle)}
}

mesh_data_destroy :: proc(mesh: ^Mesh_Data, allocator := context.allocator) {
	delete(mesh.vertices, allocator)
	delete(mesh.indices, allocator)
	mesh.vertices = nil
	mesh.indices = nil
}
