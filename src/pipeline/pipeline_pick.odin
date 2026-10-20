#+build !js
package pipeline

import "core:math/linalg"

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
