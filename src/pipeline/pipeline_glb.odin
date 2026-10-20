#+build !js
package pipeline

import "core:encoding/endian"
import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:mem/virtual"
import "core:strings"

GLB_MAGIC :: 0x46546C67
GLB_CHUNK_JSON :: 0x4E4F534A
GLB_CHUNK_BINARY :: 0x004E4942
GLTF_TRIANGLES :: 4

Gltf_Node :: struct {
	name:        string,
	mesh:        Maybe(int),
	children:    []int,
	translation: []f32,
	rotation:    []f32,
	scale:       []f32,
	matrix_values: []f32 `json:"matrix"`,
}

Gltf_Primitive :: struct {
	attributes: map[string]int,
	indices:    Maybe(int),
	mode:       Maybe(int),
}

Gltf_Mesh :: struct {
	primitives: []Gltf_Primitive,
}

Gltf_Accessor :: struct {
	bufferView:    Maybe(int),
	byteOffset:    int,
	componentType: int,
	count:         int,
	type:          string,
}

Gltf_Buffer_View :: struct {
	byteOffset: int,
	byteLength: int,
	byteStride: int,
}

Gltf_Document :: struct {
	nodes:       []Gltf_Node,
	meshes:      []Gltf_Mesh,
	accessors:   []Gltf_Accessor,
	bufferViews: []Gltf_Buffer_View,
}

// A node's translation, rotation (a unit quaternion x, y, z, w) and scale.
Node_Transform :: struct {
	translation: [3]f32,
	rotation:    quaternion128,
	scale:       [3]f32,
}

// The JSON document and the binary chunk of a GLB container. The problem
// text lives in context.temp_allocator.
split_glb :: proc(data: []byte) -> (document_text, binary: []byte, problem: string) {
	if len(data) < 20 || endian.unchecked_get_u32le(data[0:]) != GLB_MAGIC {
		return nil, nil, "glb: not a GLB file"
	}
	json_length := int(endian.unchecked_get_u32le(data[12:]))
	if endian.unchecked_get_u32le(data[16:]) != GLB_CHUNK_JSON || 20 + json_length > len(data) {
		return nil, nil, "glb: the first chunk is not a whole JSON chunk"
	}
	binary_offset := 20 + json_length
	if binary_offset + 8 > len(data) {
		return data[20:binary_offset], nil, ""
	}
	binary_length := int(endian.unchecked_get_u32le(data[binary_offset:]))
	if endian.unchecked_get_u32le(data[binary_offset + 4:]) != GLB_CHUNK_BINARY || binary_offset + 8 + binary_length > len(data) {
		return nil, nil, "glb: the second chunk is not a whole BIN chunk"
	}
	return data[20:binary_offset], data[binary_offset + 8:][:binary_length], ""
}

// The nodes that are no other node's child, as tools/models/mesh_blob.py
// finds them.
root_nodes :: proc(document: Gltf_Document, allocator := context.allocator) -> [dynamic]int {
	is_child := make([]bool, len(document.nodes))
	defer delete(is_child)
	for node in document.nodes {
		for child in node.children {
			if child >= 0 && child < len(is_child) {
				is_child[child] = true
			}
		}
	}
	roots := make([dynamic]int, allocator)
	for child, index in is_child {
		if !child {
			append(&roots, index)
		}
	}
	return roots
}

vector_or :: proc(values: []f32, fallback: [3]f32) -> [3]f32 {
	return len(values) == 3 ? {values[0], values[1], values[2]} : fallback
}

node_transform :: proc(node: Gltf_Node) -> (transform: Node_Transform, problem: string) {
	if len(node.matrix_values) != 0 {
		return {}, fmt.tprintf("glb: node %q carries a matrix, which the pipeline does not take", node.name)
	}
	transform.translation = vector_or(node.translation, {0, 0, 0})
	transform.scale = vector_or(node.scale, {1, 1, 1})
	transform.rotation = 1
	if len(node.rotation) == 4 {
		transform.rotation = quaternion(x = node.rotation[0], y = node.rotation[1], z = node.rotation[2], w = node.rotation[3])
	}
	return transform, ""
}

transform_point :: proc(transform: Node_Transform, point: [3]f32) -> [3]f32 {
	return linalg.quaternion_mul_vector3(transform.rotation, point * transform.scale) + transform.translation
}

component_bytes :: proc(component_type: int) -> int {
	switch component_type {
	case 5121:
		return 1
	case 5123:
		return 2
	case 5125, 5126:
		return 4
	}
	return 0
}

type_width :: proc(type: string) -> int {
	switch type {
	case "SCALAR":
		return 1
	case "VEC3":
		return 3
	}
	return 0
}

read_component :: proc(data: []byte, component_type: int) -> f64 {
	switch component_type {
	case 5121:
		return f64(data[0])
	case 5123:
		return f64(endian.unchecked_get_u16le(data))
	case 5125:
		return f64(endian.unchecked_get_u32le(data))
	case 5126:
		return f64(transmute(f32)endian.unchecked_get_u32le(data))
	}
	return 0
}

// Where an accessor's elements start, their stride and their size,
// checked against the binary chunk.
accessor_layout :: proc(document: Gltf_Document, binary: []byte, accessor: Gltf_Accessor) -> (start, stride, element_size: int, problem: string) {
	view_index, has_view := accessor.bufferView.?
	if !has_view || view_index < 0 || view_index >= len(document.bufferViews) {
		return 0, 0, 0, "glb: an accessor without a buffer view"
	}
	element_size = component_bytes(accessor.componentType) * type_width(accessor.type)
	if element_size == 0 {
		return 0, 0, 0, fmt.tprintf("glb: unsupported accessor component type %d of type %s", accessor.componentType, accessor.type)
	}
	view := document.bufferViews[view_index]
	stride = view.byteStride != 0 ? view.byteStride : element_size
	start = view.byteOffset + accessor.byteOffset
	if accessor.count > 0 && (start < 0 || start + stride * (accessor.count - 1) + element_size > len(binary)) {
		return 0, 0, 0, "glb: an accessor reaches past the binary chunk"
	}
	return start, stride, element_size, ""
}

read_vectors :: proc(document: Gltf_Document, binary: []byte, accessor_index: int) -> (vectors: [][3]f32, problem: string) {
	if accessor_index < 0 || accessor_index >= len(document.accessors) {
		return nil, "glb: an attribute names no accessor"
	}
	accessor := document.accessors[accessor_index]
	if accessor.type != "VEC3" || accessor.componentType != 5126 {
		return nil, "glb: a position or normal accessor is not float VEC3"
	}
	start, stride, _, layout_problem := accessor_layout(document, binary, accessor)
	if layout_problem != "" {
		return nil, layout_problem
	}
	vectors = make([][3]f32, accessor.count)
	for &vector, index in vectors {
		element := binary[start + stride * index:]
		for axis in 0 ..< 3 {
			vector[axis] = f32(read_component(element[4 * axis:], 5126))
		}
	}
	return vectors, ""
}

read_indices :: proc(document: Gltf_Document, binary: []byte, accessor_index: int) -> (indices: []u32, problem: string) {
	if accessor_index < 0 || accessor_index >= len(document.accessors) {
		return nil, "glb: the indices name no accessor"
	}
	accessor := document.accessors[accessor_index]
	if accessor.type != "SCALAR" || accessor.componentType == 5126 {
		return nil, "glb: the indices are not unsigned SCALAR"
	}
	start, stride, _, layout_problem := accessor_layout(document, binary, accessor)
	if layout_problem != "" {
		return nil, layout_problem
	}
	indices = make([]u32, accessor.count)
	for &value, index in indices {
		value = u32(read_component(binary[start + stride * index:], accessor.componentType))
	}
	return indices, ""
}

// The indices of a primitive without any: a plain triangle list.
list_indices :: proc(vertex_count: int) -> []u32 {
	indices := make([]u32, vertex_count)
	for &value, index in indices {
		value = u32(index)
	}
	return indices
}

face_normal :: proc(a, b, c: [3]f32) -> [3]f32 {
	return linalg.normalize0(linalg.cross(b - a, c - a))
}

// Appends one primitive to the mesh as the given piece, in the node's
// transform. Without normals each face gets its own three vertices with
// the face normal.
append_primitive :: proc(mesh: ^Pipeline_Mesh, transform: Node_Transform, positions, normals: [][3]f32, indices: []u32, piece: u32) {
	base := u32(len(mesh.positions))
	for start := 0; start + 3 <= len(indices); start += 3 {
		corners := [3]u32{indices[start], indices[start + 1], indices[start + 2]}
		if normals == nil {
			a, b, c := transform_point(transform, positions[corners[0]]), transform_point(transform, positions[corners[1]]), transform_point(transform, positions[corners[2]])
			normal := face_normal(a, b, c)
			first := u32(len(mesh.positions))
			append(&mesh.positions, a, b, c)
			append(&mesh.normals, normal, normal, normal)
			corners = {first, first + 1, first + 2}
		} else {
			corners += base
		}
		append(&mesh.triangles, corners)
		append(&mesh.pieces, piece)
		append(&mesh.parts, PART_NONE)
	}
	if normals == nil {
		return
	}
	for position, index in positions {
		append(&mesh.positions, transform_point(transform, position))
		append(&mesh.normals, linalg.quaternion_mul_vector3(transform.rotation, normals[index]))
	}
}

check_indices :: proc(indices: []u32, vertex_count: int) -> (problem: string) {
	for value in indices {
		if int(value) >= vertex_count {
			return fmt.tprintf("glb: index %d at or past the vertex count %d", value, vertex_count)
		}
	}
	return ""
}

read_primitive :: proc(mesh: ^Pipeline_Mesh, document: Gltf_Document, binary: []byte, primitive: Gltf_Primitive, transform: Node_Transform, piece: u32) -> (problem: string) {
	if mode, has_mode := primitive.mode.?; has_mode && mode != GLTF_TRIANGLES {
		return fmt.tprintf("glb: a primitive of mode %d, not triangles", mode)
	}
	position_accessor, has_positions := primitive.attributes["POSITION"]
	if !has_positions {
		return "glb: a primitive without POSITION"
	}
	positions: [][3]f32
	positions, problem = read_vectors(document, binary, position_accessor)
	defer delete(positions)
	if problem != "" {
		return
	}
	normals: [][3]f32
	if normal_accessor, has_normals := primitive.attributes["NORMAL"]; has_normals {
		normals, problem = read_vectors(document, binary, normal_accessor)
	}
	defer delete(normals)
	if problem != "" {
		return
	}
	if normals != nil && len(normals) != len(positions) {
		return fmt.tprintf("glb: %d positions but %d normals", len(positions), len(normals))
	}
	indices: []u32
	if index_accessor, has_indices := primitive.indices.?; has_indices {
		indices, problem = read_indices(document, binary, index_accessor)
	} else {
		indices = list_indices(len(positions))
	}
	defer delete(indices)
	if problem == "" {
		problem = check_indices(indices, len(positions))
	}
	if problem != "" {
		return
	}
	append_primitive(mesh, transform, positions, normals, indices, piece)
	return ""
}

read_node :: proc(mesh: ^Pipeline_Mesh, document: Gltf_Document, binary: []byte, node_index: int) -> (problem: string) {
	node := document.nodes[node_index]
	mesh_index, has_mesh := node.mesh.?
	if !has_mesh {
		return ""
	}
	if mesh_index < 0 || mesh_index >= len(document.meshes) {
		return fmt.tprintf("glb: node %q names no mesh", node.name)
	}
	transform: Node_Transform
	transform, problem = node_transform(node)
	if problem != "" {
		return
	}
	name := node.name != "" ? strings.clone(node.name) : fmt.aprintf("node_%d", node_index)
	append(&mesh.piece_names, name)
	piece := u32(len(mesh.piece_names) - 1)
	for primitive in document.meshes[mesh_index].primitives {
		problem = read_primitive(mesh, document, binary, primitive, transform, piece)
		if problem != "" {
			return
		}
	}
	return ""
}

// Reads a GLB into a mesh: every root node with a mesh becomes a piece
// named by the node, its node transform applied, every part none. The
// problem text lives in context.temp_allocator, and on a problem the
// mesh is empty.
read_glb :: proc(data: []byte) -> (mesh: Pipeline_Mesh, problem: string) {
	document_text, binary: []byte
	document_text, binary, problem = split_glb(data)
	if problem != "" {
		return
	}
	arena: virtual.Arena
	if virtual.arena_init_growing(&arena) != nil {
		return {}, "glb: no memory for the JSON document"
	}
	defer virtual.arena_destroy(&arena)
	document: Gltf_Document
	if error := json.unmarshal(document_text, &document, allocator = virtual.arena_allocator(&arena)); error != nil {
		return {}, fmt.tprintf("glb: the JSON chunk does not parse: %v", error)
	}
	roots := root_nodes(document)
	defer delete(roots)
	for node_index in roots {
		problem = read_node(&mesh, document, binary, node_index)
		if problem != "" {
			pipeline_mesh_destroy(&mesh)
			return {}, problem
		}
	}
	return mesh, ""
}
