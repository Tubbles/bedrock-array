#+build !js
package pipeline

import "core:fmt"
import "core:math"
import "core:strings"

// The axis of the input that becomes +z.
Front :: enum {
	Plus_X,
	Minus_X,
	Plus_Z,
	Minus_Z,
}

Select_Kind :: enum {
	Pieces,
	Part,
	Box,
	Sphere,
	Strokes,
}

Stroke :: struct {
	position: [3]f32,
	radius:   f32,
}

// Which triangles a step acts on, by the centroid of each triangle.
// A non empty within_part narrows any kind to that part.
Select :: struct {
	kind:        Select_Kind,
	pieces:      []string,
	part:        string,
	minimum:     [3]f32,
	maximum:     [3]f32,
	centre:      [3]f32,
	radius:      f32,
	strokes:     []Stroke,
	within_part: string,
}

// The quarter turn about y that brings the front axis to +z, the
// turns of tools/models/parts.py.
turn_to_front :: proc(front: Front, vector: [3]f32) -> [3]f32 {
	x, y, z := vector.x, vector.y, vector.z
	switch front {
	case .Plus_X:
		return {-z, y, x}
	case .Minus_X:
		return {z, y, -x}
	case .Minus_Z:
		return {-x, y, -z}
	case .Plus_Z:
	}
	return vector
}

// Moves the bounding box's bottom centre to the origin, scales the mesh
// to the height and turns its front to +z.
step_transform :: proc(mesh: ^Pipeline_Mesh, front: Front, height: f32) {
	minimum, maximum := pipeline_mesh_bounds(mesh^)
	centre := [3]f32{(minimum.x + maximum.x) / 2, minimum.y, (minimum.z + maximum.z) / 2}
	extent := maximum.y - minimum.y
	factor: f32 = extent > 0 ? height / extent : 1
	for &position in mesh.positions {
		position = turn_to_front(front, (position - centre) * factor)
	}
	for &normal in mesh.normals {
		normal = turn_to_front(front, normal)
	}
}

weld_cell :: proc(position: [3]f32, metres: f32) -> [3]i32 {
	return {i32(math.floor(position.x / metres)), i32(math.floor(position.y / metres)), i32(math.floor(position.z / metres))}
}

is_degenerate :: proc(triangle: [3]u32) -> bool {
	return triangle[0] == triangle[1] || triangle[1] == triangle[2] || triangle[0] == triangle[2]
}

// Keeps the triangles whose flag is false, with their pieces and parts.
keep_triangles :: proc(mesh: ^Pipeline_Mesh, drop: []bool) {
	kept := 0
	for index in 0 ..< len(mesh.triangles) {
		if drop[index] {
			continue
		}
		mesh.triangles[kept] = mesh.triangles[index]
		mesh.pieces[kept] = mesh.pieces[index]
		mesh.parts[kept] = mesh.parts[index]
		kept += 1
	}
	resize(&mesh.triangles, kept)
	resize(&mesh.pieces, kept)
	resize(&mesh.parts, kept)
}

// Merges the vertices that share a cell of the given size, keeping the
// first vertex of each cell, and drops the triangles that become
// degenerate. Vertices just across a cell border stay apart.
step_weld :: proc(mesh: ^Pipeline_Mesh, metres: f32) {
	if metres <= 0 {
		return
	}
	first_in_cell := make(map[[3]i32]u32)
	defer delete(first_in_cell)
	remap := make([]u32, len(mesh.positions))
	defer delete(remap)
	for position, index in mesh.positions {
		cell := weld_cell(position, metres)
		first, found := first_in_cell[cell]
		if !found {
			first = u32(index)
			first_in_cell[cell] = first
		}
		remap[index] = first
	}
	drop := make([]bool, len(mesh.triangles))
	defer delete(drop)
	for &triangle, index in mesh.triangles {
		triangle = {remap[triangle[0]], remap[triangle[1]], remap[triangle[2]]}
		drop[index] = is_degenerate(triangle)
	}
	keep_triangles(mesh, drop)
	compact_vertices(mesh)
}

inside_box :: proc(point, minimum, maximum: [3]f32) -> bool {
	return point.x >= minimum.x && point.y >= minimum.y && point.z >= minimum.z && point.x <= maximum.x && point.y <= maximum.y && point.z <= maximum.z
}

inside_sphere :: proc(point, centre: [3]f32, radius: f32) -> bool {
	offset := point - centre
	return offset.x * offset.x + offset.y * offset.y + offset.z * offset.z <= radius * radius
}

inside_any_stroke :: proc(point: [3]f32, strokes: []Stroke) -> bool {
	for stroke in strokes {
		if inside_sphere(point, stroke.position, stroke.radius) {
			return true
		}
	}
	return false
}

piece_listed :: proc(mesh: Pipeline_Mesh, piece: u32, names: []string) -> bool {
	for name in names {
		if mesh.piece_names[piece] == name {
			return true
		}
	}
	return false
}

part_named :: proc(mesh: Pipeline_Mesh, part: u16, name: string) -> bool {
	return part != PART_NONE && mesh.part_names[part] == name
}

triangle_selected :: proc(mesh: Pipeline_Mesh, select: Select, index: int) -> bool {
	if select.within_part != "" && !part_named(mesh, mesh.parts[index], select.within_part) {
		return false
	}
	centroid := triangle_centroid(mesh, mesh.triangles[index])
	switch select.kind {
	case .Pieces:
		return piece_listed(mesh, mesh.pieces[index], select.pieces)
	case .Part:
		return part_named(mesh, mesh.parts[index], select.part)
	case .Box:
		return inside_box(centroid, select.minimum, select.maximum)
	case .Sphere:
		return inside_sphere(centroid, select.centre, select.radius)
	case .Strokes:
		return inside_any_stroke(centroid, select.strokes)
	}
	return false
}

// One flag per triangle, true where the select takes it.
select_triangles :: proc(mesh: Pipeline_Mesh, select: Select, allocator := context.allocator) -> []bool {
	selected := make([]bool, len(mesh.triangles), allocator)
	for index in 0 ..< len(mesh.triangles) {
		selected[index] = triangle_selected(mesh, select, index)
	}
	return selected
}

// Gives the selected triangles the named part, adding the name.
step_assign :: proc(mesh: ^Pipeline_Mesh, part: string, selected: []bool) {
	part_index, _ := pipeline_mesh_part_index(mesh, part, add = true)
	for flag, index in selected {
		if flag {
			mesh.parts[index] = part_index
		}
	}
}

// Removes the selected triangles and the vertices only they used.
step_delete :: proc(mesh: ^Pipeline_Mesh, selected: []bool) {
	keep_triangles(mesh, selected)
	compact_vertices(mesh)
}

// Quarter turns about y, counterclockwise seen from above: one turn
// takes +x to -z.
quarter_turn :: proc(vector: [3]f32, turn: int) -> [3]f32 {
	result := vector
	for _ in 0 ..< ((turn % 4) + 4) % 4 {
		result = {result.z, result.y, -result.x}
	}
	return result
}

copy_piece_name :: proc(mesh: Pipeline_Mesh) -> string {
	count := 1
	for name in mesh.piece_names {
		if strings.has_prefix(name, "copy_") {
			count += 1
		}
	}
	return fmt.aprintf("copy_%d", count)
}

// Adds a copy of the selected triangles, turned about `from` and moved
// so `from` lands on `to`, as a new piece named copy_<n> with the parts
// of the originals.
step_copy :: proc(mesh: ^Pipeline_Mesh, selected: []bool, from, to: [3]f32, turn: int) {
	append(&mesh.piece_names, copy_piece_name(mesh^))
	piece := u32(len(mesh.piece_names) - 1)
	remap := make(map[u32]u32)
	defer delete(remap)
	triangle_count := len(mesh.triangles)
	for index in 0 ..< triangle_count {
		if !selected[index] {
			continue
		}
		copied: [3]u32
		for vertex, corner in mesh.triangles[index] {
			new_vertex, found := remap[vertex]
			if !found {
				new_vertex = u32(len(mesh.positions))
				remap[vertex] = new_vertex
				append(&mesh.positions, quarter_turn(mesh.positions[vertex] - from, turn) + to)
				append(&mesh.normals, quarter_turn(mesh.normals[vertex], turn))
			}
			copied[corner] = new_vertex
		}
		append(&mesh.triangles, copied)
		append(&mesh.pieces, piece)
		append(&mesh.parts, mesh.parts[index])
	}
}

// How many triangles each stroke takes by centroid, for the editor.
stroke_triangle_counts :: proc(mesh: Pipeline_Mesh, strokes: []Stroke, allocator := context.allocator) -> []int {
	counts := make([]int, len(strokes), allocator)
	for triangle in mesh.triangles {
		centroid := triangle_centroid(mesh, triangle)
		for stroke, index in strokes {
			if inside_sphere(centroid, stroke.position, stroke.radius) {
				counts[index] += 1
			}
		}
	}
	return counts
}
