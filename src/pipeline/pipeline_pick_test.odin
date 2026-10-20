#+build !js
package pipeline

import "core:log"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:testing"
import "core:time"

@(test)
test_ray_pick :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	position, triangle, hit := ray_pick(mesh, {2.75, 1, 0.25}, {0, -1, 0})
	testing.expect(t, hit)
	testing.expect_value(t, triangle, 2)
	expect_near(t, position, {2.75, 0, 0.25})
	_, _, from_below := ray_pick(mesh, {0.5, -1, 0.5}, {0, 1, 0})
	testing.expect(t, from_below)
	_, _, between := ray_pick(mesh, {1.5, 1, 0.5}, {0, -1, 0})
	testing.expect(t, !between)
	_, _, away := ray_pick(mesh, {0.5, 1, 0.5}, {0, 1, 0})
	testing.expect(t, !away)
}

// The nearer of two stacked triangles is the one picked.
@(test)
test_ray_pick_nearest :: proc(t: ^testing.T) {
	mesh: Pipeline_Mesh
	defer pipeline_mesh_destroy(&mesh)
	append(&mesh.positions, [3]f32{0, 0, 0}, [3]f32{1, 0, 0}, [3]f32{0, 0, 1}, [3]f32{0, 1, 0}, [3]f32{1, 1, 0}, [3]f32{0, 1, 1})
	append(&mesh.triangles, [3]u32{0, 1, 2}, [3]u32{3, 4, 5})
	position, triangle, hit := ray_pick(mesh, {0.2, 5, 0.2}, {0, -1, 0})
	testing.expect(t, hit)
	testing.expect_value(t, triangle, 1)
	testing.expect_value(t, position.y, f32(1))
}

// A box from minimum to maximum, each face divided into steps by steps
// squares of two triangles.
subdivided_box :: proc(minimum, maximum: [3]f32, steps: int) -> (mesh: Pipeline_Mesh) {
	for axis in 0 ..< 3 {
		across, up := (axis + 1) % 3, (axis + 2) % 3
		for side in 0 ..< 2 {
			first := u32(len(mesh.positions))
			for row in 0 ..= steps {
				for column in 0 ..= steps {
					position: [3]f32
					position[axis] = maximum[axis] if side == 1 else minimum[axis]
					position[across] = minimum[across] + (maximum[across] - minimum[across]) * f32(column) / f32(steps)
					position[up] = minimum[up] + (maximum[up] - minimum[up]) * f32(row) / f32(steps)
					append(&mesh.positions, position)
				}
			}
			for row in 0 ..< steps {
				for column in 0 ..< steps {
					corner := first + u32(row * (steps + 1) + column)
					next_row := corner + u32(steps + 1)
					append(&mesh.triangles, [3]u32{corner, corner + 1, next_row + 1}, [3]u32{corner, next_row + 1, next_row})
				}
			}
		}
	}
	return mesh
}

random_point :: proc(minimum, maximum: [3]f32) -> [3]f32 {
	return {rand.float32_range(minimum.x, maximum.x), rand.float32_range(minimum.y, maximum.y), rand.float32_range(minimum.z, maximum.z)}
}

random_direction :: proc() -> [3]f32 {
	for {
		direction := random_point({-1, -1, -1}, {1, 1, 1})
		length := linalg.length(direction)
		if length > 0.1 && length <= 1 do return direction / length
	}
}

// A subdivided box with a soup of random triangles inside, rays from
// inside and outside: the grid's pick is the plain loop's.
@(test)
test_pick_grid_equals_ray_pick :: proc(t: ^testing.T) {
	state := rand.create(20261020)
	context.random_generator = rand.default_random_generator(&state)
	mesh := subdivided_box({-1, -0.5, -2}, {1, 0.5, 2}, 12)
	defer pipeline_mesh_destroy(&mesh)
	for _ in 0 ..< 1000 {
		first := u32(len(mesh.positions))
		centre := random_point({-1, -0.5, -2}, {1, 0.5, 2})
		for _ in 0 ..< 3 do append(&mesh.positions, centre + random_point({-0.2, -0.2, -0.2}, {0.2, 0.2, 0.2}))
		append(&mesh.triangles, [3]u32{first, first + 1, first + 2})
	}
	grid := pick_grid_build(mesh)
	defer pick_grid_destroy(&grid)
	hits := 0
	for _ in 0 ..< 2000 {
		origin := random_point({-3, -3, -3}, {3, 3, 3})
		// Half the rays aim into the box, half go anywhere.
		direction := linalg.normalize(random_point({-1, -0.5, -2}, {1, 0.5, 2}) - origin) if rand.int_max(2) == 0 else random_direction()
		expected, expected_triangle, expected_hit := ray_pick(mesh, origin, direction)
		position, triangle, hit := pick_grid_ray(grid, mesh, origin, direction)
		testing.expect_value(t, hit, expected_hit)
		if !hit || !expected_hit do continue
		hits += 1
		testing.expect(t, abs(linalg.length(position - origin) - linalg.length(expected - origin)) < 1e-5)
		if triangle != expected_triangle {
			corners := mesh.triangles[triangle]
			distance, _ := ray_triangle(origin, direction, mesh.positions[corners[0]], mesh.positions[corners[1]], mesh.positions[corners[2]])
			testing.expectf(t, abs(distance - linalg.length(expected - origin)) < 1e-5, "triangle %d for %d", triangle, expected_triangle)
		}
	}
	testing.expect(t, hits > 500)
}

@(test)
test_pick_grid_flat_and_empty :: proc(t: ^testing.T) {
	mesh := two_quads()
	defer pipeline_mesh_destroy(&mesh)
	grid := pick_grid_build(mesh)
	defer pick_grid_destroy(&grid)
	position, triangle, hit := pick_grid_ray(grid, mesh, {2.75, 1, 0.25}, {0, -1, 0})
	testing.expect(t, hit)
	testing.expect_value(t, triangle, 2)
	expect_near(t, position, {2.75, 0, 0.25})
	_, _, between := pick_grid_ray(grid, mesh, {1.5, 1, 0.5}, {0, -1, 0})
	testing.expect(t, !between)
	empty: Pipeline_Mesh
	empty_grid := pick_grid_build(empty)
	defer pick_grid_destroy(&empty_grid)
	_, _, none := pick_grid_ray(empty_grid, empty, {0, 1, 0}, {0, -1, 0})
	testing.expect(t, !none)
}

// About 1.5 M triangles: prints the build time and the mean pick time.
@(test)
test_pick_grid_timing :: proc(t: ^testing.T) {
	state := rand.create(7)
	context.random_generator = rand.default_random_generator(&state)
	mesh := subdivided_box({-1.5, 0, -1}, {1.5, 2, 1}, 354)
	defer pipeline_mesh_destroy(&mesh)
	build_start := time.tick_now()
	grid := pick_grid_build(mesh)
	defer pick_grid_destroy(&grid)
	build_time := time.tick_since(build_start)
	hits := 0
	pick_start := time.tick_now()
	for _ in 0 ..< 1000 {
		origin := random_point({-3, -1, -3}, {3, 3, 3})
		_, _, hit := pick_grid_ray(grid, mesh, origin, linalg.normalize(random_point({-1.5, 0, -1}, {1.5, 2, 1}) - origin))
		if hit do hits += 1
	}
	pick_time := time.tick_since(pick_start) / 1000
	log.infof("pick grid: %d triangles, %v cells, %d entries, build %v, mean pick %v, %d hits", len(mesh.triangles), grid.counts, len(grid.cell_triangles), build_time, pick_time, hits)
	testing.expect(t, hits == 1000)
	testing.expect(t, pick_time < 10 * time.Millisecond)
}

// The smelter's model when present: prints the grid's build time.
@(test)
test_pick_grid_smelter_timing :: proc(t: ^testing.T) {
	if !os.exists(SMELTER_MODEL) {
		log.infof("skipped: %s is absent", SMELTER_MODEL)
		return
	}
	data, _ := os.read_entire_file_from_path(SMELTER_MODEL, context.allocator)
	defer delete(data)
	mesh, problem := read_glb(data)
	defer pipeline_mesh_destroy(&mesh)
	testing.expect_value(t, problem, "")
	build_start := time.tick_now()
	grid := pick_grid_build(mesh)
	defer pick_grid_destroy(&grid)
	log.infof("smelter pick grid: %d triangles, %v cells, %d entries, build %v", len(mesh.triangles), grid.counts, len(grid.cell_triangles), time.tick_since(build_start))
}
