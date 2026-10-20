#+build !js
package app

import "core:slice"
import "core:testing"
import engine "../engine"
import pipeline "../pipeline"

@(test)
test_editor_default_shown :: proc(t: ^testing.T) {
	eleven := editor_default_shown(11)
	defer delete(eleven)
	testing.expect(t, slice.equal(eleven[:], []int{0, 3, 6, 10}))
	two := editor_default_shown(2)
	defer delete(two)
	testing.expect(t, slice.equal(two[:], []int{0, 1}))
	none := editor_default_shown(0)
	testing.expect_value(t, len(none), 0)
}

@(test)
test_editor_shown_add_and_drop :: proc(t: ^testing.T) {
	shown := make([dynamic]int)
	defer delete(shown)
	append(&shown, 0, 6)
	editor_shown_add(&shown, 3)
	editor_shown_add(&shown, 3)
	testing.expect(t, slice.equal(shown[:], []int{0, 3, 6}))
	editor_shown_add(&shown, 9)
	editor_shown_add(&shown, 1)
	testing.expect(t, slice.equal(shown[:], []int{0, 3, 6, 9}))
	editor_shown_drop(&shown, 3)
	editor_shown_drop(&shown, 4)
	testing.expect(t, slice.equal(shown[:], []int{0, 6, 9}))
}

@(test)
test_editor_grid_cells :: proc(t: ^testing.T) {
	area := Editor_Rectangle{320, 0, 960, 720}
	testing.expect_value(t, editor_grid_cells(1, area)[0], area)
	two := editor_grid_cells(2, area)
	testing.expect_value(t, two[0], Editor_Rectangle{320, 0, 480, 720})
	testing.expect_value(t, two[1], Editor_Rectangle{800, 0, 480, 720})
	four := editor_grid_cells(4, area)
	testing.expect_value(t, four[2], Editor_Rectangle{320, 360, 480, 360})
	testing.expect_value(t, four[3], Editor_Rectangle{800, 360, 480, 360})
	testing.expect_value(t, editor_view_area({1280, 720}), area)
}

@(test)
test_editor_first_row :: proc(t: ^testing.T) {
	testing.expect_value(t, editor_first_row(3, 10, 11), 0)
	testing.expect_value(t, editor_first_row(10, 10, 11), 1)
	testing.expect_value(t, editor_first_row(5, 10, 4), 0)
}

// Two triangles of part 1, one of part 0 and one of no part, sharing vertices.
@(private = "file")
test_mesh :: proc() -> (mesh: pipeline.Pipeline_Mesh) {
	append(&mesh.positions, [3]f32{0, 0, 0}, [3]f32{1, 0, 0}, [3]f32{0, 1, 0}, [3]f32{1, 1, 0})
	append(&mesh.normals, [3]f32{0, 0, 1}, [3]f32{0, 0, 1}, [3]f32{0, 0, 1}, [3]f32{0, 0, 1})
	append(&mesh.triangles, [3]u32{0, 1, 2}, [3]u32{1, 3, 2}, [3]u32{0, 1, 3}, [3]u32{2, 1, 0})
	append(&mesh.parts, 1, 1, 0, pipeline.PART_NONE)
	append(&mesh.pieces, 0, 0, 0, 0)
	append(&mesh.part_names, "body", "lid")
	return
}

@(test)
test_editor_part_meshes :: proc(t: ^testing.T) {
	mesh := test_mesh()
	defer {
		delete(mesh.positions)
		delete(mesh.normals)
		delete(mesh.triangles)
		delete(mesh.parts)
		delete(mesh.pieces)
		delete(mesh.part_names)
	}
	buckets := editor_part_triangles(mesh)
	defer {
		for bucket in buckets do delete(bucket)
		delete(buckets)
	}
	testing.expect_value(t, len(buckets), 3)
	testing.expect(t, slice.equal(buckets[0][:], []int{2}))
	testing.expect(t, slice.equal(buckets[1][:], []int{0, 1}))
	testing.expect(t, slice.equal(buckets[2][:], []int{3}))
	data := editor_mesh_data(mesh, buckets[1][:])
	defer engine.mesh_data_destroy(&data)
	testing.expect_value(t, len(data.vertices), 4)
	testing.expect(t, slice.equal(data.indices, []u32{0, 1, 2, 1, 3, 2}))
	lid := editor_mesh_data(mesh, buckets[0][:])
	defer engine.mesh_data_destroy(&lid)
	testing.expect_value(t, len(lid.vertices), 3)
	testing.expect_value(t, lid.vertices[2].position, [3]f32{1, 1, 0})
}

@(test)
test_editor_false_colour_tint :: proc(t: ^testing.T) {
	albedo := [3]f32{0.5, 0.5, 0.5}
	testing.expect_value(t, editor_false_colour_tint(-1, albedo), EDITOR_PART_NONE_COLOUR * 2)
	testing.expect_value(t, editor_false_colour_tint(len(EDITOR_PALETTE), albedo), EDITOR_PALETTE[0] * 2)
}

@(test)
test_editor_keys_text :: proc(t: ^testing.T) {
	pieces := []string{"a", "b"}
	assign := pipeline.Step{op = .Assign, enabled = true, part = "skirt", select = {kind = .Pieces, pieces = pieces}}
	testing.expect_value(t, editor_keys_text(assign), "skirt, 2 pieces")
	transform := pipeline.Step{op = .Transform, front = .Plus_X, height = 1}
	testing.expect_value(t, editor_keys_text(transform), "+x, height 1")
	within := pipeline.Step{op = .Delete, select = {kind = .Part, part = "body", within_part = "lid"}}
	testing.expect_value(t, editor_keys_text(within), "part body in lid")
}

@(test)
test_editor_parse_brief_parts :: proc(t: ^testing.T) {
	data := `id = "x"
parts = [
	{ name = "skirt" material = "painted_steel" role = "base" }
	{ name = "hearth" material = "furnace_glow" }
]`
	parts := editor_parse_brief_parts(transmute([]byte)data)
	defer {
		for part in parts {
			delete(part.name)
			delete(part.material)
		}
		delete(parts)
	}
	testing.expect_value(t, len(parts), 2)
	material, found := editor_brief_material(parts[:], "hearth")
	testing.expect(t, found)
	testing.expect_value(t, material, "furnace_glow")
	_, missing := editor_brief_material(parts[:], "lid")
	testing.expect(t, !missing)
	broken := editor_parse_brief_parts(transmute([]byte)string("parts = 3"))
	testing.expect_value(t, len(broken), 0)
}
