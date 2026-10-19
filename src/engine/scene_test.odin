#+build !js
package engine

import "core:strings"
import "core:testing"

@(private = "file")
TEST_LIBRARY_TEXT :: `
painted_steel = { albedo = [0.2, 0.24, 0.3], roughness = 0.55, metallic = 0 }
copper = { albedo = [0.95, 0.64, 0.54], roughness = 0.3, metallic = 1 }
`

@(test)
test_parse_scene_reads_the_example :: proc(t: ^testing.T) {
	library, library_problem := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	testing.expect_value(t, library_problem, "")
	text := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
	{ shape = "cylinder", radius = 0.5, height = 1, segments = 24, position = [1.5, 0.5, 0], material = "copper" }
]
lights = [
	{ position = [-1.5, 0.3, 1.5], colour = [1, 0.6, 0.3], intensity = 2, range = 4 }
]
`
	scene, problem := parse_scene(transmute([]byte)text, library)
	defer scene_destroy(&scene)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(scene.items), 2)
	testing.expect_value(t, len(scene.lights), 1)
	if len(scene.items) == 2 {
		testing.expect_value(t, scene.items[1].shape, Scene_Shape.Cylinder)
		testing.expect_value(t, scene.items[1].segments, 24)
		copper, found := material_id_by_name(library, "copper")
		testing.expect(t, found)
		testing.expect_value(t, scene.items[1].material, copper)
	}
}

@(test)
test_parse_scene_rejects_an_unknown_material :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	text := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
	{ shape = "box", size = [1, 1, 1], position = [2, 0.5, 0], material = "unknown_name" }
]
`
	scene, problem := parse_scene(transmute([]byte)text, library)
	defer scene_destroy(&scene)
	testing.expectf(t, strings.contains(problem, "item 1: material unknown_name not in the library"), "problem: %q", problem)
	testing.expect_value(t, len(scene.items), 0)
}

@(test)
test_parse_scene_rejects_an_unknown_key :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	text := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "copper", colour = [1, 0, 0] }
]
lights = []
`
	scene, problem := parse_scene(transmute([]byte)text, library)
	defer scene_destroy(&scene)
	testing.expectf(t, strings.contains(problem, "item 0: unknown key colour"), "problem: %q", problem)
	testing.expect_value(t, len(scene.items), 0)
}

@(test)
test_scene_item_mesh_by_shape :: proc(t: ^testing.T) {
	box, _ := scene_item_mesh(Scene_Item{shape = .Box, size = {1, 1, 1}}, nil)
	defer mesh_data_destroy(&box)
	testing.expect_value(t, len(box.vertices), 24)
	cylinder, _ := scene_item_mesh(Scene_Item{shape = .Cylinder, radius = 0.5, height = 1, segments = 8}, nil)
	defer mesh_data_destroy(&cylinder)
	testing.expect_value(t, len(cylinder.vertices), 36)
	room, _ := scene_item_mesh(Scene_Item{shape = .Room, size = {1, 1, 1}}, nil)
	defer mesh_data_destroy(&room)
	testing.expect_value(t, len(room.vertices), 24)
}

@(test)
test_parse_scene_ambient_default_and_value :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	without_ambient := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
]
`
	default_scene, default_problem := parse_scene(transmute([]byte)without_ambient, library)
	defer scene_destroy(&default_scene)
	testing.expect_value(t, default_problem, "")
	testing.expect_value(t, default_scene.ambient, 0.15)
	with_ambient := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
ambient = 0.02
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
]
`
	dark_scene, dark_problem := parse_scene(transmute([]byte)with_ambient, library)
	defer scene_destroy(&dark_scene)
	testing.expect_value(t, dark_problem, "")
	testing.expect_value(t, dark_scene.ambient, 0.02)
}

@(test)
test_parse_scene_hemisphere_defaults_to_ambient :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	without_hemisphere := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
]
`
	default_scene, default_problem := parse_scene(transmute([]byte)without_hemisphere, library)
	defer scene_destroy(&default_scene)
	testing.expect_value(t, default_problem, "")
	testing.expect_value(t, default_scene.sky_colour, [3]f32{0.15, 0.15, 0.15})
	testing.expect_value(t, default_scene.ground_colour, [3]f32{0.15, 0.15, 0.15})
	with_hemisphere := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
sky_colour = [0.2, 0.3, 0.5]
ground_colour = [0.1, 0.1, 0.1]
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
]
`
	sky_scene, sky_problem := parse_scene(transmute([]byte)with_hemisphere, library)
	defer scene_destroy(&sky_scene)
	testing.expect_value(t, sky_problem, "")
	testing.expect_value(t, sky_scene.sky_colour, [3]f32{0.2, 0.3, 0.5})
	testing.expect_value(t, sky_scene.ground_colour, [3]f32{0.1, 0.1, 0.1})
}

// Every shipped scene parses against the shipped library, so a typo in a
// scene file fails here and not only in a browser console.
@(test)
test_shipped_scenes_parse :: proc(t: ^testing.T) {
	library, library_problem := parse_material_library(#load("../../data/materials/library.sjson"))
	defer material_library_destroy(&library)
	testing.expect_value(t, library_problem, "")
	scenes := [][]byte {
		#load("../../data/demos/light/scene.sjson"),
		#load("../../data/demos/cave/scene.sjson"),
		#load("../../data/demos/surface/scene.sjson"),
	}
	for data in scenes {
		scene, problem := parse_scene(data, library)
		defer scene_destroy(&scene)
		testing.expect_value(t, problem, "")
		testing.expect(t, len(scene.items) > 0)
	}
}

@(test)
test_scene_item_half_extents :: proc(t: ^testing.T) {
	box := Scene_Item{shape = .Box, size = {2, 4, 6}}
	testing.expect_value(t, scene_item_half_extents(box, {}), [3]f32{1, 2, 3})
	cylinder := Scene_Item{shape = .Cylinder, radius = 0.5, height = 2, segments = 24}
	testing.expect_value(t, scene_item_half_extents(cylinder, {}), [3]f32{0.5, 1, 0.5})
}

@(test)
test_parse_scene_reads_a_mesh_item :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	text := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "mesh", file = "part.mesh", scale = 2, position = [0, 0, 0], material = "painted_steel" }
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
]
`
	scene, problem := parse_scene(transmute([]byte)text, library)
	defer scene_destroy(&scene)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(scene.items), 2)
	if len(scene.items) == 2 {
		testing.expect_value(t, scene.items[0].shape, Scene_Shape.Mesh)
		testing.expect_value(t, scene.items[0].file, "part.mesh")
		testing.expect_value(t, scene.items[0].scale, 2)
		testing.expect_value(t, scene.items[1].scale, 1)
	}
}

@(test)
test_parse_scene_rejects_a_mesh_item_without_a_file :: proc(t: ^testing.T) {
	library, _ := parse_material_library(transmute([]byte)string(TEST_LIBRARY_TEXT))
	defer material_library_destroy(&library)
	text := `
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "mesh", position = [0, 0, 0], material = "painted_steel" }
]
`
	scene, problem := parse_scene(transmute([]byte)text, library)
	defer scene_destroy(&scene)
	testing.expectf(t, strings.contains(problem, "item 0: file missing"), "problem: %q", problem)
	testing.expect_value(t, len(scene.items), 0)
}
