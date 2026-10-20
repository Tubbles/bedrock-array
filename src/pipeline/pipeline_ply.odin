#+build !js
package pipeline

import "core:bytes"
import "core:encoding/endian"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:strconv"
import "core:strings"

// The selected triangles with only the vertices they use, renumbered
// from zero.
Triangle_Subset :: struct {
	positions: [dynamic][3]f32,
	normals:   [dynamic][3]f32,
	triangles: [dynamic][3]u32,
}

gather_triangles :: proc(mesh: Pipeline_Mesh, selected: []bool) -> Triangle_Subset {
	subset: Triangle_Subset
	remap := make(map[u32]u32)
	defer delete(remap)
	for triangle, index in mesh.triangles {
		if !selected[index] {
			continue
		}
		renumbered: [3]u32
		for vertex, corner in triangle {
			new_vertex, found := remap[vertex]
			if !found {
				new_vertex = u32(len(subset.positions))
				remap[vertex] = new_vertex
				append(&subset.positions, mesh.positions[vertex])
				append(&subset.normals, mesh.normals[vertex])
			}
			renumbered[corner] = new_vertex
		}
		append(&subset.triangles, renumbered)
	}
	return subset
}

triangle_subset_destroy :: proc(subset: ^Triangle_Subset) {
	delete(subset.positions)
	delete(subset.normals)
	delete(subset.triangles)
}

append_u32le :: proc(buffer: ^[dynamic]byte, value: u32) {
	encoded: [4]byte
	endian.unchecked_put_u32le(encoded[:], value)
	append(buffer, ..encoded[:])
}

append_f32le :: proc(buffer: ^[dynamic]byte, value: f32) {
	append_u32le(buffer, transmute(u32)value)
}

// The selected triangles as the binary little endian PLY
// tools/models/parts.py writes: x y z nx ny nz floats, faces as a uchar
// count and int indices.
ply_bytes :: proc(mesh: Pipeline_Mesh, selected: []bool, allocator := context.allocator) -> []byte {
	subset := gather_triangles(mesh, selected)
	defer triangle_subset_destroy(&subset)
	buffer := make([dynamic]byte, allocator)
	header := fmt.tprintf("ply\nformat binary_little_endian 1.0\nelement vertex %d\nproperty float x\nproperty float y\nproperty float z\nproperty float nx\nproperty float ny\nproperty float nz\nelement face %d\nproperty list uchar int vertex_indices\nend_header\n", len(subset.positions), len(subset.triangles))
	append(&buffer, header)
	for position, index in subset.positions {
		for value in position {
			append_f32le(&buffer, value)
		}
		for value in subset.normals[index] {
			append_f32le(&buffer, value)
		}
	}
	for triangle in subset.triangles {
		append(&buffer, 3)
		for vertex in triangle {
			append_u32le(&buffer, vertex)
		}
	}
	return buffer[:]
}

// Writes the selected triangles to the path as PLY. The problem text
// lives in context.temp_allocator.
write_ply :: proc(path: string, mesh: Pipeline_Mesh, selected: []bool) -> (problem: string) {
	data := ply_bytes(mesh, selected)
	defer delete(data)
	if error := os.write_entire_file(path, data); error != nil {
		return fmt.tprintf("ply: writing %s: %v", path, error)
	}
	return ""
}

Ply_Property :: struct {
	name:       string,
	type:       string,
	count_type: string, // empty for a scalar, the count's type for a list
}

Ply_Element :: struct {
	name:       string,
	count:      int,
	properties: [dynamic]Ply_Property,
}

ply_type_bytes :: proc(type: string) -> int {
	switch type {
	case "char", "uchar", "int8", "uint8":
		return 1
	case "short", "ushort", "int16", "uint16":
		return 2
	case "int", "uint", "float", "int32", "uint32", "float32":
		return 4
	case "double", "float64":
		return 8
	}
	return 0
}

ply_read_value :: proc(data: []byte, type: string) -> f64 {
	switch type {
	case "char", "int8":
		return f64(i8(data[0]))
	case "uchar", "uint8":
		return f64(data[0])
	case "short", "int16":
		return f64(i16(endian.unchecked_get_u16le(data)))
	case "ushort", "uint16":
		return f64(endian.unchecked_get_u16le(data))
	case "int", "int32":
		return f64(i32(endian.unchecked_get_u32le(data)))
	case "uint", "uint32":
		return f64(endian.unchecked_get_u32le(data))
	case "float", "float32":
		return f64(transmute(f32)endian.unchecked_get_u32le(data))
	case "double", "float64":
		return transmute(f64)endian.unchecked_get_u64le(data)
	}
	return 0
}

ply_elements_destroy :: proc(elements: [dynamic]Ply_Element) {
	for element in elements {
		delete(element.properties)
	}
	delete(elements)
}

// Parses one header line into the elements. The strings point into the
// header text.
ply_header_line :: proc(elements: ^[dynamic]Ply_Element, line: string) -> (problem: string) {
	words := strings.fields(line, context.temp_allocator)
	if len(words) == 0 {
		return ""
	}
	switch words[0] {
	case "ply", "comment", "obj_info":
	case "format":
		if len(words) < 2 || words[1] != "binary_little_endian" {
			return fmt.tprintf("ply: format %q, only binary_little_endian is read", line)
		}
	case "element":
		count, ok := strconv.parse_int(len(words) == 3 ? words[2] : "")
		if !ok || count < 0 {
			return fmt.tprintf("ply: element line %q", line)
		}
		append(elements, Ply_Element{name = words[1], count = count})
	case "property":
		if len(elements) == 0 {
			return "ply: a property before any element"
		}
		properties := &elements[len(elements) - 1].properties
		if len(words) == 5 && words[1] == "list" && ply_type_bytes(words[2]) != 0 && ply_type_bytes(words[3]) != 0 {
			append(properties, Ply_Property{name = words[4], type = words[3], count_type = words[2]})
		} else if len(words) == 3 && ply_type_bytes(words[1]) != 0 {
			append(properties, Ply_Property{name = words[2], type = words[1]})
		} else {
			return fmt.tprintf("ply: property line %q", line)
		}
	case:
		return fmt.tprintf("ply: header line %q", line)
	}
	return ""
}

// The elements of the header and where the body starts.
parse_ply_header :: proc(data: []byte) -> (elements: [dynamic]Ply_Element, body_start: int, problem: string) {
	END :: "end_header\n"
	end := bytes.index(data, transmute([]byte)string(END))
	if len(data) < 4 || string(data[:4]) != "ply\n" || end < 0 {
		return nil, 0, "ply: not a PLY file with an end_header line"
	}
	header := string(data[:end])
	for line in strings.split_lines_iterator(&header) {
		problem = ply_header_line(&elements, strings.trim_right(line, "\r"))
		if problem != "" {
			ply_elements_destroy(elements)
			return nil, 0, problem
		}
	}
	return elements, end + len(END), ""
}

property_index :: proc(element: Ply_Element, name: string) -> int {
	for property, index in element.properties {
		if property.name == name {
			return index
		}
	}
	return -1
}

// Reads one vertex record into the mesh and returns its byte length.
read_ply_vertex :: proc(mesh: ^Pipeline_Mesh, element: Ply_Element, axes: [6]int, data: []byte, offset: int) -> (length: int, problem: string) {
	values: [6]f32
	cursor := offset
	for property, property_number in element.properties {
		if property.count_type != "" {
			return 0, "ply: a list property on a vertex"
		}
		size := ply_type_bytes(property.type)
		if cursor + size > len(data) {
			return 0, "ply: the vertices run past the end"
		}
		for axis, slot in axes {
			if axis == property_number {
				values[slot] = f32(ply_read_value(data[cursor:], property.type))
			}
		}
		cursor += size
	}
	append(&mesh.positions, [3]f32{values[0], values[1], values[2]})
	append(&mesh.normals, [3]f32{values[3], values[4], values[5]})
	return cursor - offset, ""
}

// Reads one face record, a fan of triangles over its vertex_indices, and
// returns its byte length.
read_ply_face :: proc(mesh: ^Pipeline_Mesh, element: Ply_Element, data: []byte, offset: int) -> (length: int, problem: string) {
	cursor := offset
	for property in element.properties {
		if property.count_type == "" {
			cursor += ply_type_bytes(property.type)
			continue
		}
		count_size, index_size := ply_type_bytes(property.count_type), ply_type_bytes(property.type)
		if cursor + count_size > len(data) {
			return 0, "ply: the faces run past the end"
		}
		count := int(ply_read_value(data[cursor:], property.count_type))
		cursor += count_size
		if cursor + count * index_size > len(data) {
			return 0, "ply: the faces run past the end"
		}
		if property.name == "vertex_indices" || property.name == "vertex_index" {
			corner :: proc(data: []byte, cursor, size, number: int, type: string) -> u32 {
				return u32(ply_read_value(data[cursor + size * number:], type))
			}
			for number in 2 ..< max(count, 2) {
				append(&mesh.triangles, [3]u32{corner(data, cursor, index_size, 0, property.type), corner(data, cursor, index_size, number - 1, property.type), corner(data, cursor, index_size, number, property.type)})
				append(&mesh.pieces, 0)
				append(&mesh.parts, PART_NONE)
			}
		}
		cursor += count * index_size
	}
	if cursor > len(data) {
		return 0, "ply: the faces run past the end"
	}
	return cursor - offset, ""
}

// Area weighted vertex normals, for a PLY without any.
compute_vertex_normals :: proc(mesh: ^Pipeline_Mesh) {
	for &normal in mesh.normals {
		normal = {}
	}
	for triangle in mesh.triangles {
		a, b, c := mesh.positions[triangle[0]], mesh.positions[triangle[1]], mesh.positions[triangle[2]]
		area_normal := linalg.cross(b - a, c - a)
		for vertex in triangle {
			mesh.normals[vertex] += area_normal
		}
	}
	for &normal in mesh.normals {
		normal = linalg.normalize0(normal)
	}
}

read_ply_body :: proc(mesh: ^Pipeline_Mesh, elements: [dynamic]Ply_Element, data: []byte, body_start: int) -> (problem: string) {
	cursor := body_start
	has_normals := false
	for element in elements {
		axes := [6]int{-1, -1, -1, -1, -1, -1}
		for name, slot in ([]string{"x", "y", "z", "nx", "ny", "nz"}) {
			axes[slot] = property_index(element, name)
		}
		if element.name == "vertex" {
			if axes[0] < 0 || axes[1] < 0 || axes[2] < 0 {
				return "ply: vertices without x, y and z"
			}
			has_normals = axes[3] >= 0 && axes[4] >= 0 && axes[5] >= 0
		}
		for _ in 0 ..< element.count {
			length: int
			switch element.name {
			case "vertex":
				length, problem = read_ply_vertex(mesh, element, axes, data, cursor)
			case "face":
				length, problem = read_ply_face(mesh, element, data, cursor)
			case:
				return fmt.tprintf("ply: element %q, only vertex and face are read", element.name)
			}
			if problem != "" {
				return
			}
			cursor += length
		}
	}
	for triangle in mesh.triangles {
		for vertex in triangle {
			if int(vertex) >= len(mesh.positions) {
				return fmt.tprintf("ply: index %d at or past the vertex count %d", vertex, len(mesh.positions))
			}
		}
	}
	if !has_normals {
		compute_vertex_normals(mesh)
	}
	return ""
}

// Reads a binary little endian PLY, the format write_ply writes or
// MeshLab's (properties in any order, the ones not named x, y, z, nx,
// ny, nz skipped). The mesh is one piece named "ply", every part none,
// and without normals in the file it gets area weighted vertex normals.
// The problem text lives in context.temp_allocator, and on a problem the
// mesh is empty.
read_ply :: proc(data: []byte) -> (mesh: Pipeline_Mesh, problem: string) {
	elements, body_start, header_problem := parse_ply_header(data)
	if header_problem != "" {
		return {}, header_problem
	}
	defer ply_elements_destroy(elements)
	append(&mesh.piece_names, strings.clone("ply"))
	problem = read_ply_body(&mesh, elements, data, body_start)
	if problem != "" {
		pipeline_mesh_destroy(&mesh)
		return {}, problem
	}
	return mesh, ""
}
