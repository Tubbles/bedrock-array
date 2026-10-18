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
