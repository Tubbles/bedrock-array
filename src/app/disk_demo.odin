package app

import "base:runtime"
import "core:os"
import "core:fmt"

// A demo read from disk at run time, for inspecting a pipeline step without
// embedding it: <directory>/scene.sjson and every file of <directory>/meshes/.
// The data lives until the program ends. ok is false when either is missing.
demo_from_directory :: proc(directory: string) -> (demo: Demo, ok: bool) {
	scene, scene_error := os.read_entire_file_from_path(fmt.tprintf("%s/scene.sjson", directory), context.allocator)
	if scene_error != nil do return demo, false
	meshes_path := fmt.tprintf("%s/meshes", directory)
	entries, list_error := os.read_all_directory_by_path(meshes_path, context.temp_allocator)
	if list_error != nil do return demo, false
	meshes := make([dynamic]runtime.Load_Directory_File)
	for entry in entries {
		if entry.type != .Regular do continue
		data, read_error := os.read_entire_file_from_path(entry.fullpath, context.allocator)
		if read_error != nil do return demo, false
		append(&meshes, runtime.Load_Directory_File{name = entry.name, data = data})
	}
	return Demo{name = directory, description = directory, scene = scene, meshes = meshes[:]}, true
}
