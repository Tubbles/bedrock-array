#+build !js
package pipeline

import "core:slice"
import "core:strings"

// A part index that names no part.
PART_NONE :: max(u16)

// The one mesh the pipeline steps run on. Each triangle has a piece (an
// index into piece_names) and a part (an index into part_names, or
// PART_NONE). The mesh owns its arrays and its name strings.
Pipeline_Mesh :: struct {
	positions:   [dynamic][3]f32,
	normals:     [dynamic][3]f32,
	triangles:   [dynamic][3]u32,
	pieces:      [dynamic]u32,
	parts:       [dynamic]u16,
	piece_names: [dynamic]string,
	part_names:  [dynamic]string,
}

clone_names :: proc(names: []string, allocator := context.allocator) -> [dynamic]string {
	result := make([dynamic]string, 0, len(names), allocator)
	for name in names {
		append(&result, strings.clone(name, allocator))
	}
	return result
}

pipeline_mesh_clone :: proc(mesh: Pipeline_Mesh, allocator := context.allocator) -> Pipeline_Mesh {
	return Pipeline_Mesh {
		positions = slice.clone_to_dynamic(mesh.positions[:], allocator),
		normals = slice.clone_to_dynamic(mesh.normals[:], allocator),
		triangles = slice.clone_to_dynamic(mesh.triangles[:], allocator),
		pieces = slice.clone_to_dynamic(mesh.pieces[:], allocator),
		parts = slice.clone_to_dynamic(mesh.parts[:], allocator),
		piece_names = clone_names(mesh.piece_names[:], allocator),
		part_names = clone_names(mesh.part_names[:], allocator),
	}
}

pipeline_mesh_destroy :: proc(mesh: ^Pipeline_Mesh) {
	for name in mesh.piece_names {
		delete(name)
	}
	for name in mesh.part_names {
		delete(name)
	}
	delete(mesh.positions)
	delete(mesh.normals)
	delete(mesh.triangles)
	delete(mesh.pieces)
	delete(mesh.parts)
	delete(mesh.piece_names)
	delete(mesh.part_names)
	mesh^ = {}
}

// A mesh for a step that changes no vertex and no triangle: its geometry
// (positions, normals, triangles, pieces and piece names) aliases the
// mesh's, its parts and part names are its own copies. The geometry stays
// the mesh's, so the result is freed with pipeline_mesh_destroy_parts and
// only while the mesh lives, and nothing may append to its geometry.
pipeline_mesh_share_geometry :: proc(mesh: Pipeline_Mesh) -> Pipeline_Mesh {
	shared := mesh
	shared.parts = slice.clone_to_dynamic(mesh.parts[:])
	shared.part_names = clone_names(mesh.part_names[:])
	return shared
}

// Frees what pipeline_mesh_share_geometry copied, leaving the geometry.
pipeline_mesh_destroy_parts :: proc(mesh: ^Pipeline_Mesh) {
	for name in mesh.part_names {
		delete(name)
	}
	delete(mesh.parts)
	delete(mesh.part_names)
	mesh^ = {}
}

// The axis aligned bounds of every position, zero for an empty mesh.
pipeline_mesh_bounds :: proc(mesh: Pipeline_Mesh) -> (minimum, maximum: [3]f32) {
	if len(mesh.positions) == 0 {
		return
	}
	minimum = mesh.positions[0]
	maximum = mesh.positions[0]
	for position in mesh.positions {
		minimum = {min(minimum.x, position.x), min(minimum.y, position.y), min(minimum.z, position.z)}
		maximum = {max(maximum.x, position.x), max(maximum.y, position.y), max(maximum.z, position.z)}
	}
	return
}

// The index of the named part, PART_NONE when absent.
find_part :: proc(mesh: Pipeline_Mesh, name: string) -> (u16, bool) {
	for part_name, index in mesh.part_names {
		if part_name == name {
			return u16(index), true
		}
	}
	return PART_NONE, false
}

// The index of the named part. With add set, a missing name is added
// and its new index returned.
pipeline_mesh_part_index :: proc(mesh: ^Pipeline_Mesh, name: string, add := false) -> (u16, bool) {
	if index, found := find_part(mesh^, name); found {
		return index, true
	}
	if !add || len(mesh.part_names) >= int(PART_NONE) {
		return PART_NONE, false
	}
	append(&mesh.part_names, strings.clone(name))
	return u16(len(mesh.part_names) - 1), true
}

triangle_centroid :: proc(mesh: Pipeline_Mesh, triangle: [3]u32) -> [3]f32 {
	return (mesh.positions[triangle[0]] + mesh.positions[triangle[1]] + mesh.positions[triangle[2]]) / 3
}

// Drops the vertices no triangle uses and renumbers the triangles,
// keeping the vertices in the order the triangles first use them.
compact_vertices :: proc(mesh: ^Pipeline_Mesh) {
	remap := make([]u32, len(mesh.positions))
	defer delete(remap)
	slice.fill(remap, max(u32))
	positions := make([dynamic][3]f32, 0, len(mesh.positions))
	normals := make([dynamic][3]f32, 0, len(mesh.normals))
	for &triangle in mesh.triangles {
		for &vertex in triangle {
			if remap[vertex] == max(u32) {
				remap[vertex] = u32(len(positions))
				append(&positions, mesh.positions[vertex])
				append(&normals, mesh.normals[vertex])
			}
			vertex = remap[vertex]
		}
	}
	delete(mesh.positions)
	delete(mesh.normals)
	mesh.positions = positions
	mesh.normals = normals
}
