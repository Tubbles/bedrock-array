#+build !js
package app

import "core:math/linalg"
import "core:slice"
import "core:testing"
import engine "../engine"
import pipeline "../pipeline"

@(test)
test_editor_keep_near :: proc(t: ^testing.T) {
	testing.expect(t, editor_keep_near(false, 11))
	testing.expect(t, !editor_keep_near(false, 13))
	testing.expect(t, editor_keep_near(true, 19))
	testing.expect(t, !editor_keep_near(true, 21))
}

@(test)
test_editor_ray_box :: proc(t: ^testing.T) {
	box := Editor_Bounds{{0, 0, 0}, {1, 1, 1}}
	distance, met := editor_ray_box({-2, 0.5, 0.5}, {1, 0, 0}, box)
	testing.expect(t, met)
	testing.expect_value(t, distance, 2)
	inside, met_inside := editor_ray_box({0.5, 0.5, 0.5}, {0, 1, 0}, box)
	testing.expect(t, met_inside)
	testing.expect_value(t, inside, 0)
	_, behind := editor_ray_box({2, 0.5, 0.5}, {1, 0, 0}, box)
	testing.expect(t, !behind)
	_, beside := editor_ray_box({-2, 2, 0.5}, {1, 0, 0}, box)
	testing.expect(t, !beside)
}

// Down the line the first machine is met first, from the side the one in
// front, and a ray meeting none picks the machine nearest the camera.
@(test)
test_editor_pick_box :: proc(t: ^testing.T) {
	boxes := []Editor_Bounds{editor_world_bounds(EDITOR_DEFAULT_BOUNDS, 0), editor_world_bounds(EDITOR_DEFAULT_BOUNDS, 1)}
	testing.expect_value(t, editor_pick_box({-3, 0.5, 0}, {1, 0, 0}, boxes), 0)
	testing.expect_value(t, editor_pick_box({EDITOR_MACHINE_SPACING, 0.5, 5}, {0, 0, -1}, boxes), 1)
	testing.expect_value(t, editor_pick_box({4, 5, 0}, {0, 1, 0}, boxes), 1)
	testing.expect_value(t, editor_pick_box({0, 0, 0}, {1, 0, 0}, nil), -1)
}

@(test)
test_editor_floor_bounds :: proc(t: ^testing.T) {
	floor := editor_floor_bounds(3)
	testing.expect_value(t, floor.minimum, [3]f32{-EDITOR_FLOOR_MARGIN, -EDITOR_FLOOR_THICKNESS, -EDITOR_FLOOR_MARGIN})
	testing.expect_value(t, floor.maximum, [3]f32{2 * EDITOR_MACHINE_SPACING + EDITOR_FLOOR_MARGIN, 0, EDITOR_FLOOR_MARGIN})
}

@(test)
test_editor_fly_looking_at :: proc(t: ^testing.T) {
	fly := editor_fly_looking_at({0, 1, 0}, {3, 0, 4})
	camera := engine.fly_camera(fly, engine.SCENE_VIEW_VERTICAL_FOV, 0.02, 100)
	forward := linalg.normalize(camera.target - camera.position)
	expected := linalg.normalize([3]f32{3, -1, 4})
	testing.expect(t, linalg.length(forward - expected) < 1e-5)
}

@(test)
test_editor_project :: proc(t: ^testing.T) {
	camera := engine.fly_camera(editor_fly_looking_at({0, 0, 0}, {1, 0, 0}), engine.SCENE_VIEW_VERTICAL_FOV, 0.02, 100)
	point, in_front := editor_project(camera, {200, 100}, {5, 0, 0})
	testing.expect(t, in_front)
	testing.expect(t, linalg.length(point - [2]f32{100, 50}) < 1e-3)
	_, behind := editor_project(camera, {200, 100}, {-5, 0, 0})
	testing.expect(t, !behind)
}

@(test)
test_editor_plaque_lines :: proc(t: ^testing.T) {
	run: pipeline.Run
	append(&run.pipeline.steps, pipeline.Step{op = .Import, enabled = true}, pipeline.Step{op = .Weld, metres = 0.001})
	append(&run.status, pipeline.Step_Status{state = .Done}, pipeline.Step_Status{state = .Failed, message = "no file"})
	defer {
		delete(run.pipeline.steps)
		delete(run.status)
	}
	lines := editor_plaque_lines(run, 1)
	testing.expect_value(t, len(lines), 3)
	if len(lines) == 3 {
		testing.expect_value(t, lines[0], "1 weld off")
		testing.expect_value(t, lines[1], "metres 0.001")
		testing.expect_value(t, lines[2], "failed: no file")
	}
	testing.expect_value(t, len(editor_plaque_lines(run, 0)), 2)
	far := editor_plaque_title(lines, .Failed)
	testing.expect_value(t, len(far), 2)
	if len(far) == 2 do testing.expect_value(t, far[1], "failed: no file")
	testing.expect_value(t, len(editor_plaque_title(lines, .Done)), 1)
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
	vertices := editor_vertices(mesh)
	defer delete(vertices)
	testing.expect_value(t, len(vertices), 4)
	testing.expect_value(t, vertices[3].position, [3]f32{1, 1, 0})
	body, body_extents := editor_part_indices(mesh, buckets[1][:])
	defer delete(body)
	testing.expect(t, slice.equal(body, []u32{0, 1, 2, 1, 3, 2}))
	testing.expect_value(t, body_extents, [3]f32{1, 1, 0})
	lid, lid_extents := editor_part_indices(mesh, buckets[0][:])
	defer delete(lid)
	testing.expect(t, slice.equal(lid, []u32{0, 1, 3}))
	testing.expect_value(t, lid_extents, [3]f32{1, 1, 0})
}

@(test)
test_editor_mesh_bounds :: proc(t: ^testing.T) {
	mesh := test_mesh()
	defer {
		delete(mesh.positions)
		delete(mesh.normals)
		delete(mesh.triangles)
		delete(mesh.parts)
		delete(mesh.pieces)
		delete(mesh.part_names)
	}
	bounds := editor_mesh_bounds(mesh)
	testing.expect_value(t, bounds.minimum, [3]f32{0, 0, 0})
	testing.expect_value(t, bounds.maximum, [3]f32{1, 1, 0})
	testing.expect_value(t, editor_mesh_bounds({}), EDITOR_DEFAULT_BOUNDS)
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

// Each mode's hints name exactly the actions its handling takes, every
// row of the mode once, each with a keyboard or mouse input and a pad one.
@(test)
test_editor_mode_hints_cover_the_actions :: proc(t: ^testing.T) {
	for mode in Editor_Mode {
		hints := editor_mode_hints(mode)
		actions: bit_set[Editor_Action]
		for hint in hints {
			actions += {hint.binding_action}
			testing.expectf(t, hint.keys != "" && hint.pad != "", "%v %s lacks keys or pad", mode, hint.action)
		}
		testing.expectf(t, actions == EDITOR_MODE_ACTIONS[mode], "%v: hints %v, handled %v", mode, actions, EDITOR_MODE_ACTIONS[mode])
		rows := 0
		for row in EDITOR_BINDINGS {
			if mode not_in row.modes do continue
			rows += 1
			found := false
			for hint in hints do found ||= hint.binding_action == row.action && hint.action == row.label
			testing.expectf(t, found, "%v: no hint for %v", mode, row.action)
		}
		testing.expect_value(t, len(hints), rows)
	}
}

// No two rows of a mode share a key with its modifiers or a pad button
// with the shoulder modifier.
@(test)
test_editor_bindings_do_not_clash :: proc(t: ^testing.T) {
	for mode in Editor_Mode {
		for first, first_index in EDITOR_BINDINGS {
			if mode not_in first.modes do continue
			for second in EDITOR_BINDINGS[first_index + 1:] {
				if mode not_in second.modes do continue
				same_key := first.key != .KEY_NULL && first.key == second.key && first.alt == second.alt && first.control == second.control
				same_pad := first.pad & second.pad != {} && first.pad_modifier == second.pad_modifier
				testing.expectf(t, !same_key && !same_pad, "%v: %v and %v clash", mode, first.action, second.action)
			}
		}
	}
}

@(test)
test_editor_hint_names :: proc(t: ^testing.T) {
	insert, _ := editor_binding_of(.Walk, .Insert_Menu)
	testing.expect_value(t, editor_hint_text({editor_keys_name(insert), editor_pad_name(insert), insert.label, insert.action}), "I / LB + A: insert step")
	rise, _ := editor_binding_of(.Panel, .Rise_Sink)
	testing.expect_value(t, editor_pad_name(rise), "LB + d-pad up down")
	move, _ := editor_binding_of(.Walk, .Move_Up)
	testing.expect_value(t, editor_keys_name(move), "Alt Up")
	paint, _ := editor_binding_of(.Brush, .Paint)
	testing.expect_value(t, editor_keys_name(paint), "left click")
	testing.expect_value(t, editor_pad_name(paint), "RT")
	save, _ := editor_binding_of(.Walk, .Save)
	testing.expect_value(t, editor_keys_name(save), "Ctrl S")
}

@(test)
test_editor_hint_rows :: proc(t: ^testing.T) {
	rows, count := editor_hint_rows({40, 40, 40, 100}, 100, 10)
	testing.expect(t, slice.equal(rows, []int{0, 0, 1, 2}))
	testing.expect_value(t, count, 3)
	_, none := editor_hint_rows({}, 100, 10)
	testing.expect_value(t, none, 0)
}

@(test)
test_editor_input_for_mode :: proc(t: ^testing.T) {
	input := Editor_Input{pressed = {.Delete, .Up, .Save}, radius_notches = 1, walk = {1, 0, 0}}
	panel := editor_input_for_mode(input, .Panel)
	testing.expect_value(t, panel.pressed, bit_set[Editor_Action]{.Up, .Save})
	testing.expect_value(t, panel.radius_notches, 0)
	testing.expect_value(t, panel.walk, [3]f32{1, 0, 0})
}
