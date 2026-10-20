#+build !js
package pipeline

import "core:math"
import "core:math/linalg"
import "core:slice"

// Below this the ray runs along the triangle's plane and misses it.
RAY_PARALLEL_EPSILON :: f32(1e-12)

// The distance along the ray to the triangle (a, b, c), either side
// facing, by Moller and Trumbore; hit is false for a miss or a triangle
// behind the origin.
ray_triangle :: proc(origin, direction, a, b, c: [3]f32) -> (distance: f32, hit: bool) {
	edge_one, edge_two := b - a, c - a
	cross_two := linalg.cross(direction, edge_two)
	determinant := linalg.dot(edge_one, cross_two)
	if abs(determinant) < RAY_PARALLEL_EPSILON do return 0, false
	inverse := 1 / determinant
	offset := origin - a
	u := linalg.dot(offset, cross_two) * inverse
	if u < 0 || u > 1 do return 0, false
	cross_one := linalg.cross(offset, edge_one)
	v := linalg.dot(direction, cross_one) * inverse
	if v < 0 || u + v > 1 do return 0, false
	distance = linalg.dot(edge_two, cross_one) * inverse
	return distance, distance > 0
}

// The nearest triangle the ray meets, a plain loop over every triangle,
// and the point it meets it at.
ray_pick :: proc(mesh: Pipeline_Mesh, origin, direction: [3]f32) -> (position: [3]f32, triangle: int, hit: bool) {
	nearest := max(f32)
	for corners, index in mesh.triangles {
		a, b, c := mesh.positions[corners[0]], mesh.positions[corners[1]], mesh.positions[corners[2]]
		distance, met := ray_triangle(origin, direction, a, b, c)
		if met && distance < nearest {
			nearest, triangle, hit = distance, index, true
		}
	}
	if hit do position = origin + direction * nearest
	return position, triangle, hit
}

// The triangles a pick grid aims for per cell, averaged over every cell.
PICK_GRID_TRIANGLES_PER_CELL :: 64
// The most cells along one axis.
PICK_GRID_MAXIMUM_CELLS :: 1024

// A uniform grid over a mesh's bounds for ray picks. Cell n holds the
// triangles whose bounds overlap it, cell_triangles[cell_starts[n]:
// cell_starts[n + 1]], in the order of the mesh. The grid holds triangle
// indices only, so it serves every mesh sharing the geometry it was built
// from, and is stale once that geometry changes.
Pick_Grid :: struct {
	minimum:        [3]f32,
	cell_size:      [3]f32,
	counts:         [3]int,
	cell_starts:    []u32,
	cell_triangles: []u32,
}

pick_grid_destroy :: proc(grid: ^Pick_Grid) {
	delete(grid.cell_starts)
	delete(grid.cell_triangles)
	grid^ = {}
}

// The cells along each axis for these extents: cubes holding about
// PICK_GRID_TRIANGLES_PER_CELL triangles each, an axis thinner than a cube
// one cell deep.
pick_grid_counts :: proc(extent: [3]f32, triangles: int) -> (counts: [3]int) {
	cells := max(f64(triangles) / PICK_GRID_TRIANGLES_PER_CELL, 1)
	thin: [3]bool
	edge: f64
	for _ in 0 ..< 3 {
		volume, axes := f64(1), 0
		for axis in 0 ..< 3 {
			if thin[axis] do continue
			volume *= f64(extent[axis])
			axes += 1
		}
		if axes == 0 do break
		edge = math.pow(volume / cells, 1 / f64(axes))
		for axis in 0 ..< 3 do thin[axis] ||= f64(extent[axis]) < edge
	}
	for axis in 0 ..< 3 {
		counts[axis] = 1 if thin[axis] || edge <= 0 else clamp(int(math.round(f64(extent[axis]) / edge)), 1, PICK_GRID_MAXIMUM_CELLS)
	}
	return counts
}

// The cell holding the point along each axis, clamped into the grid.
pick_grid_cell :: proc(grid: Pick_Grid, point: [3]f32) -> (cell: [3]int) {
	for axis in 0 ..< 3 {
		cell[axis] = clamp(int(math.floor((point[axis] - grid.minimum[axis]) / grid.cell_size[axis])), 0, grid.counts[axis] - 1)
	}
	return cell
}

pick_grid_index :: proc(grid: Pick_Grid, cell: [3]int) -> int {
	return (cell.z * grid.counts.y + cell.y) * grid.counts.x + cell.x
}

// The first and last cell the triangle's bounds overlap, the bounds grown
// by a little so a hit on a cell face is in the cells either side.
pick_grid_triangle_cells :: proc(grid: Pick_Grid, mesh: Pipeline_Mesh, corners: [3]u32) -> (first, last: [3]int) {
	a, b, c := mesh.positions[corners[0]], mesh.positions[corners[1]], mesh.positions[corners[2]]
	margin := grid.cell_size * 1e-4
	first = pick_grid_cell(grid, linalg.min(a, b, c) - margin)
	last = pick_grid_cell(grid, linalg.max(a, b, c) + margin)
	return first, last
}

// One pass over the triangles and the cells each overlaps. Counting
// (fill false) raises cursor[cell] per triangle, so with cursor the cell
// starts shifted by one it leaves the counts to sum. Filling writes each
// triangle at cursor[cell] and moves it on.
pick_grid_bin :: proc(grid: ^Pick_Grid, mesh: Pipeline_Mesh, cursor: []u32, fill: bool) {
	for corners, triangle in mesh.triangles {
		first, last := pick_grid_triangle_cells(grid^, mesh, corners)
		for z in first.z ..= last.z {
			for y in first.y ..= last.y {
				for x in first.x ..= last.x {
					index := pick_grid_index(grid^, {x, y, z})
					if fill do grid.cell_triangles[cursor[index]] = u32(triangle)
					cursor[index] += 1
				}
			}
		}
	}
}

// The grid over the mesh's bounds, its cells filled by a counting sort.
pick_grid_build :: proc(mesh: Pipeline_Mesh) -> (grid: Pick_Grid) {
	minimum, maximum := pipeline_mesh_bounds(mesh)
	padding := max(linalg.max(maximum - minimum) * 1e-4, 1e-6)
	grid.minimum = minimum - padding
	extent := maximum - minimum + 2 * padding
	grid.counts = pick_grid_counts(extent, len(mesh.triangles))
	grid.cell_size = extent / [3]f32{f32(grid.counts.x), f32(grid.counts.y), f32(grid.counts.z)}
	cell_count := grid.counts.x * grid.counts.y * grid.counts.z
	grid.cell_starts = make([]u32, cell_count + 1)
	pick_grid_bin(&grid, mesh, grid.cell_starts[1:], false)
	for index in 1 ..= cell_count do grid.cell_starts[index] += grid.cell_starts[index - 1]
	grid.cell_triangles = make([]u32, grid.cell_starts[cell_count])
	cursor := slice.clone(grid.cell_starts[:cell_count])
	defer delete(cursor)
	pick_grid_bin(&grid, mesh, cursor, true)
	return grid
}

// Where the ray enters and leaves the grid's box, hit false when it misses
// it or the box is behind the origin.
pick_grid_span :: proc(grid: Pick_Grid, origin, direction: [3]f32) -> (enter, leave: f32, hit: bool) {
	maximum := grid.minimum + grid.cell_size * [3]f32{f32(grid.counts.x), f32(grid.counts.y), f32(grid.counts.z)}
	enter, leave = 0, max(f32)
	for axis in 0 ..< 3 {
		if direction[axis] == 0 {
			if origin[axis] < grid.minimum[axis] || origin[axis] > maximum[axis] do return 0, 0, false
			continue
		}
		near := (grid.minimum[axis] - origin[axis]) / direction[axis]
		far := (maximum[axis] - origin[axis]) / direction[axis]
		if near > far do near, far = far, near
		enter, leave = max(enter, near), min(leave, far)
	}
	return enter, leave, enter <= leave
}

// The nearest hit among the cell's triangles, nearer than nearest.
pick_grid_test_cell :: proc(grid: Pick_Grid, mesh: Pipeline_Mesh, index: int, origin, direction: [3]f32, nearest: ^f32, triangle: ^int) {
	for candidate in grid.cell_triangles[grid.cell_starts[index]:grid.cell_starts[index + 1]] {
		corners := mesh.triangles[candidate]
		a, b, c := mesh.positions[corners[0]], mesh.positions[corners[1]], mesh.positions[corners[2]]
		distance, met := ray_triangle(origin, direction, a, b, c)
		if met && (distance < nearest^ || distance == nearest^ && int(candidate) < triangle^) {
			nearest^, triangle^ = distance, int(candidate)
		}
	}
}

// ray_pick through the grid built from the mesh's geometry: the cells
// along the ray in order (Amanatides and Woo), stopping after the first
// cell whose nearest hit comes before the next cell. Among triangles at
// one distance it takes the lowest index, as ray_pick does.
pick_grid_ray :: proc(grid: Pick_Grid, mesh: Pipeline_Mesh, origin, direction: [3]f32) -> (position: [3]f32, triangle: int, hit: bool) {
	enter, leave, inside := pick_grid_span(grid, origin, direction)
	if !inside || len(grid.cell_triangles) == 0 do return
	cell := pick_grid_cell(grid, origin + direction * enter)
	step, next, delta: [3]f32
	for axis in 0 ..< 3 {
		if direction[axis] == 0 {
			next[axis], delta[axis] = max(f32), max(f32)
			continue
		}
		step[axis] = 1 if direction[axis] > 0 else -1
		boundary := grid.minimum[axis] + grid.cell_size[axis] * f32(cell[axis] + (1 if direction[axis] > 0 else 0))
		next[axis] = (boundary - origin[axis]) / direction[axis]
		delta[axis] = grid.cell_size[axis] / abs(direction[axis])
	}
	nearest := max(f32)
	triangle = -1
	for {
		pick_grid_test_cell(grid, mesh, pick_grid_index(grid, cell), origin, direction, &nearest, &triangle)
		axis := 0 if next.x <= next.y && next.x <= next.z else (1 if next.y <= next.z else 2)
		if triangle >= 0 && nearest <= next[axis] do break
		if next[axis] > leave do break
		cell[axis] += int(step[axis])
		if cell[axis] < 0 || cell[axis] >= grid.counts[axis] do break
		next[axis] += delta[axis]
	}
	if triangle < 0 do return {}, 0, false
	return origin + direction * nearest, triangle, true
}
