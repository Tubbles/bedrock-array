package app

// The scene demos the app shows, their data embedded as the web pages embed it.

import "base:runtime"

Demo :: struct {
	name, description: string,
	scene:             []byte,
	meshes:            []runtime.Load_Directory_File,
}

// The material library and the textures every scene shares.
MATERIAL_LIBRARY :: #load("../../data/materials/library.sjson")
material_textures := #load_directory("../../data/materials/textures")

DEMOS := [?]Demo {
	{
		name = "light",
		description = #load("../demos/light/description.txt", string),
		scene = #load("../../data/demos/light/scene.sjson"),
	},
	{
		name = "surface",
		description = #load("../demos/surface/description.txt", string),
		scene = #load("../../data/demos/surface/scene.sjson"),
	},
	{
		name = "cave",
		description = #load("../demos/cave/description.txt", string),
		scene = #load("../../data/demos/cave/scene.sjson"),
	},
	{
		name = "models",
		description = #load("../demos/models/description.txt", string),
		scene = #load("../../data/demos/models/scene.sjson"),
		meshes = #load_directory("../../data/demos/models/meshes"),
	},
	{
		name = "decimation",
		description = #load("../demos/decimation/description.txt", string),
		scene = #load("../../data/demos/decimation/scene.sjson"),
		meshes = #load_directory("../../data/demos/decimation/meshes"),
	},
}

// The demo of that name, ok false when no demo has it.
demo_by_name :: proc(name: string) -> (demo: Demo, ok: bool) {
	for candidate in DEMOS {
		if candidate.name == name do return candidate, true
	}
	return {}, false
}
