#+build !js
package pipeline

import "core:fmt"
import "core:os"

MESH_BLOB_MAGIC :: "BAMESH01"

// One part's triangles as the engine's BAMESH01 blob (render_mesh_blob.odin):
// the magic, u32 vertex count, u32 index count, six f32 per vertex
// (position, normal), then the u32 indices, little endian, positions as
// they are.
part_blob_bytes :: proc(mesh: Pipeline_Mesh, part: u16, allocator := context.allocator) -> []byte {
	selected := make([]bool, len(mesh.triangles))
	defer delete(selected)
	for triangle_part, index in mesh.parts {
		selected[index] = triangle_part == part
	}
	subset := gather_triangles(mesh, selected)
	defer triangle_subset_destroy(&subset)
	buffer := make([dynamic]byte, allocator)
	append(&buffer, MESH_BLOB_MAGIC)
	append_u32le(&buffer, u32(len(subset.positions)))
	append_u32le(&buffer, u32(3 * len(subset.triangles)))
	for position, index in subset.positions {
		for value in position {
			append_f32le(&buffer, value)
		}
		for value in subset.normals[index] {
			append_f32le(&buffer, value)
		}
	}
	for triangle in subset.triangles {
		for vertex in triangle {
			append_u32le(&buffer, vertex)
		}
	}
	return buffer[:]
}

part_has_triangles :: proc(mesh: Pipeline_Mesh, part: u16) -> bool {
	for triangle_part in mesh.parts {
		if triangle_part == part {
			return true
		}
	}
	return false
}

// Writes one blob per part with triangles, <directory>/<part><suffix>.mesh.
// Triangles of no part are not written. The problem text lives in
// context.temp_allocator.
write_part_blobs :: proc(mesh: Pipeline_Mesh, directory, suffix: string) -> (problem: string) {
	for name, part in mesh.part_names {
		if !part_has_triangles(mesh, u16(part)) {
			continue
		}
		data := part_blob_bytes(mesh, u16(part))
		path := fmt.tprintf("%s/%s%s.mesh", directory, name, suffix)
		error := os.write_entire_file(path, data)
		delete(data)
		if error != nil {
			return fmt.tprintf("blob: writing %s: %v", path, error)
		}
	}
	return ""
}
