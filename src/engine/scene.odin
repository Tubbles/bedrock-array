package engine

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:strings"

Scene_Shape :: enum {
	Box,
	Cylinder,
	Room,
	Mesh,
}

// size for a box or a room, radius, height and segments for a cylinder, files
// (the mesh blob's file name, one per configuration or one for all) for a
// mesh. scale is a uniform scale, 1 unless a mesh sets it.
Scene_Item :: struct {
	shape:          Scene_Shape,
	size:           [3]f32,
	radius, height: f32,
	segments:       int,
	files:          []string,
	scale:          f32,
	position:       [3]f32,
	material:       Material_Id,
}

// A plaque naming what stands at position.
Scene_Label :: struct {
	text:     string,
	position: [3]f32,
}

// configurations names the scene's variants, empty for one unnamed one.
Scene :: struct {
	configurations:            []string,
	camera:                    Orbit,
	fit_width:                 f32,
	sun:                       Directional_Light,
	exposure:                  f32,
	ambient:                   f32,
	sky_colour, ground_colour: [3]f32,
	items:                     []Scene_Item,
	lights:                    []Point_Light,
	labels:                    []Scene_Label,
}

// Parses data/demos/<name>/scene.sjson against the material library. The
// problem names the key and the item or light index, and is empty when all
// is well.
// The problem text lives in context.temp_allocator, valid until its next reset.
parse_scene :: proc(data: []byte, library: Material_Library, allocator := context.allocator) -> (scene: Scene, problem: string) {
	value, error := json.parse(data, .SJSON, true, context.temp_allocator)
	defer json.destroy_value(value, context.temp_allocator)
	if error != nil {
		return {}, fmt.tprintf("not SJSON: %v", error)
	}
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, "expected an object"
	}
	for key in fields {
		switch key {
		case "configurations", "camera", "sun", "exposure", "ambient", "sky_colour", "ground_colour", "items", "lights", "labels":
		case:
			return {}, fmt.tprintf("scene: unknown key %s", key)
		}
	}
	configurations: []string
	if configurations, problem = parse_scene_configurations(fields); problem != "" {
		return {}, problem
	}
	defer delete(configurations, context.temp_allocator)
	if scene.camera, scene.fit_width, problem = parse_scene_camera(fields); problem != "" {
		return {}, problem
	}
	if scene.sun, problem = parse_scene_sun(fields); problem != "" {
		return {}, problem
	}
	if scene.exposure, problem = scene_non_negative_field("scene", "exposure", fields); problem != "" {
		return {}, problem
	}
	scene.ambient = 0.15
	if "ambient" in fields {
		if scene.ambient, problem = scene_non_negative_field("scene", "ambient", fields); problem != "" {
			return {}, problem
		}
	}
	if scene.sky_colour, problem = scene_hemisphere_colour("sky_colour", scene.ambient, fields); problem != "" {
		return {}, problem
	}
	if scene.ground_colour, problem = scene_hemisphere_colour("ground_colour", scene.ambient, fields); problem != "" {
		return {}, problem
	}
	items_array, items_problem := scene_array_field("scene", "items", fields)
	if items_problem != "" {
		return {}, items_problem
	}
	items := make([]Scene_Item, len(items_array), context.temp_allocator)
	defer delete(items, context.temp_allocator)
	for element, index in items_array {
		if items[index], problem = parse_scene_item(fmt.tprintf("item %d", index), element, library, len(configurations)); problem != "" {
			return {}, problem
		}
	}
	lights_array: json.Array
	if "lights" in fields {
		if lights_array, problem = scene_array_field("scene", "lights", fields); problem != "" {
			return {}, problem
		}
	}
	lights := make([]Point_Light, len(lights_array), context.temp_allocator)
	defer delete(lights, context.temp_allocator)
	for element, index in lights_array {
		if lights[index], problem = parse_scene_light(fmt.tprintf("light %d", index), element); problem != "" {
			return {}, problem
		}
	}
	labels_array: json.Array
	if "labels" in fields {
		if labels_array, problem = scene_array_field("scene", "labels", fields); problem != "" {
			return {}, problem
		}
	}
	labels := make([]Scene_Label, len(labels_array), context.temp_allocator)
	defer delete(labels, context.temp_allocator)
	for element, index in labels_array {
		if labels[index], problem = parse_scene_label(fmt.tprintf("label %d", index), element); problem != "" {
			return {}, problem
		}
	}
	// The names point into the parsed SJSON, freed on return.
	scene.configurations = scene_clone_strings(configurations, allocator)
	scene.items = make([]Scene_Item, len(items), allocator)
	copy(scene.items, items)
	for &item in scene.items {
		file_names := item.files
		item.files = scene_clone_strings(file_names, allocator)
		delete(file_names, context.temp_allocator)
	}
	scene.lights = make([]Point_Light, len(lights), allocator)
	copy(scene.lights, lights)
	// The texts point into the parsed SJSON too.
	scene.labels = make([]Scene_Label, len(labels), allocator)
	for label, index in labels {
		scene.labels[index] = {strings.clone(label.text, allocator), label.position}
	}
	return scene, ""
}

scene_destroy :: proc(scene: ^Scene, allocator := context.allocator) {
	for item in scene.items {
		scene_delete_strings(item.files, allocator)
	}
	delete(scene.items, allocator)
	scene_delete_strings(scene.configurations, allocator)
	scene.configurations = nil
	delete(scene.lights, allocator)
	for label in scene.labels {
		delete(label.text, allocator)
	}
	delete(scene.labels, allocator)
	scene.items = nil
	scene.lights = nil
	scene.labels = nil
}

// One unnamed configuration when the scene names none.
scene_configuration_count :: proc(scene: Scene) -> int {
	return max(1, len(scene.configurations))
}

// The file name of a mesh item's blob for the configuration; an item with one
// file serves every configuration.
scene_item_file :: proc(item: Scene_Item, configuration: int) -> string {
	return item.files[min(configuration, len(item.files) - 1)]
}

// The item's mesh by its shape, for the caller to upload and destroy. A mesh
// item's blob for the configuration is found by its file name among meshes.
// The problem text lives in context.temp_allocator, valid until its next reset.
scene_item_mesh :: proc(item: Scene_Item, configuration: int, meshes: []runtime.Load_Directory_File) -> (mesh: Mesh_Data, problem: string) {
	switch item.shape {
	case .Box:
		return box_mesh(item.size), ""
	case .Cylinder:
		return cylinder_mesh(item.radius, item.height, item.segments), ""
	case .Room:
		return room_mesh(item.size), ""
	case .Mesh:
		file_name := scene_item_file(item, configuration)
		data, found := scene_mesh_file_find(meshes, file_name)
		if !found do return {}, fmt.tprintf("mesh file %s missing", file_name)
		if mesh, problem = parse_mesh_blob(data); problem != "" {
			return {}, fmt.tprintf("%s: %s", file_name, problem)
		}
		return mesh, ""
	}
	return {}, ""
}

// The half extents of the item's mesh around its origin, for the wear rule's
// edge distance, in the mesh's own units since the shader compares them with
// the vertex position before the scale; mesh is the parsed blob of a mesh item.
scene_item_half_extents :: proc(item: Scene_Item, mesh: Mesh_Data) -> [3]f32 {
	switch item.shape {
	case .Box, .Room:
		return item.size / 2
	case .Cylinder:
		return {item.radius, item.height / 2, item.radius}
	case .Mesh:
		return mesh_half_extents(mesh)
	}
	return {}
}

@(private = "file")
scene_mesh_file_find :: proc(files: []runtime.Load_Directory_File, file_name: string) -> (data: []byte, found: bool) {
	for file in files {
		if file.name == file_name do return file.data, true
	}
	return nil, false
}

@(private = "file")
scene_clone_strings :: proc(texts: []string, allocator := context.allocator) -> []string {
	if len(texts) == 0 do return nil
	clones := make([]string, len(texts), allocator)
	for text, index in texts {
		clones[index] = strings.clone(text, allocator)
	}
	return clones
}

@(private = "file")
scene_delete_strings :: proc(texts: []string, allocator := context.allocator) {
	for text in texts {
		delete(text, allocator)
	}
	delete(texts, allocator)
}

// The names point into the parsed SJSON, in a slice of context.temp_allocator.
@(private = "file")
parse_scene_configurations :: proc(fields: json.Object) -> (configurations: []string, problem: string) {
	if "configurations" not_in fields do return nil, ""
	return scene_string_array_field("scene", "configurations", fields)
}

// The strings point into the parsed SJSON, in a slice of context.temp_allocator.
@(private = "file")
scene_string_array_field :: proc(owner, key: string, fields: json.Object) -> (texts: []string, problem: string) {
	array: json.Array
	if array, problem = scene_array_field(owner, key, fields); problem != "" {
		return nil, problem
	}
	texts = make([]string, len(array), context.temp_allocator)
	for element, index in array {
		is_string: bool
		if texts[index], is_string = element.(json.String); !is_string {
			delete(texts, context.temp_allocator)
			return nil, fmt.tprintf("%s: %s must be an array of strings", owner, key)
		}
	}
	return texts, ""
}

@(private = "file")
parse_scene_camera :: proc(fields: json.Object) -> (camera: Orbit, fit_width: f32, problem: string) {
	camera_fields: json.Object
	if camera_fields, problem = scene_object_field("scene", "camera", fields); problem != "" {
		return {}, 0, problem
	}
	if problem = scene_check_keys("camera", camera_fields, {"target", "yaw", "pitch", "distance", "fit_width"}); problem != "" {
		return {}, 0, problem
	}
	if camera.target, problem = scene_vector_field("camera", "target", camera_fields); problem != "" {
		return {}, 0, problem
	}
	if camera.yaw, problem = scene_number_field("camera", "yaw", camera_fields); problem != "" {
		return {}, 0, problem
	}
	if camera.pitch, problem = scene_number_field("camera", "pitch", camera_fields); problem != "" {
		return {}, 0, problem
	}
	if camera.distance, problem = scene_non_negative_field("camera", "distance", camera_fields); problem != "" {
		return {}, 0, problem
	}
	if "fit_width" in camera_fields {
		if fit_width, problem = scene_non_negative_field("camera", "fit_width", camera_fields); problem != "" {
			return {}, 0, problem
		}
	}
	return camera, fit_width, ""
}

@(private = "file")
parse_scene_sun :: proc(fields: json.Object) -> (sun: Directional_Light, problem: string) {
	sun_fields: json.Object
	if sun_fields, problem = scene_object_field("scene", "sun", fields); problem != "" {
		return {}, problem
	}
	if problem = scene_check_keys("sun", sun_fields, {"direction", "colour", "intensity"}); problem != "" {
		return {}, problem
	}
	if sun.direction, problem = scene_vector_field("sun", "direction", sun_fields); problem != "" {
		return {}, problem
	}
	if sun.direction == {0, 0, 0} {
		return {}, "sun: direction must not be all zero"
	}
	if sun.colour, problem = scene_vector_field("sun", "colour", sun_fields); problem != "" {
		return {}, problem
	}
	if sun.intensity, problem = scene_non_negative_field("sun", "intensity", sun_fields); problem != "" {
		return {}, problem
	}
	return sun, ""
}

@(private = "file")
parse_scene_item :: proc(owner: string, value: json.Value, library: Material_Library, configuration_names: int) -> (item: Scene_Item, problem: string) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("%s: expected an object", owner)
	}
	shape_name: string
	if shape_name, problem = scene_string_field(owner, "shape", fields); problem != "" {
		return {}, problem
	}
	item.scale = 1
	switch shape_name {
	case "box":
		item.shape = .Box
		if item.size, problem = parse_scene_box(owner, fields); problem != "" {
			return {}, problem
		}
	case "room":
		item.shape = .Room
		if item.size, problem = parse_scene_box(owner, fields); problem != "" {
			return {}, problem
		}
	case "cylinder":
		item.shape = .Cylinder
		if item.radius, item.height, item.segments, problem = parse_scene_cylinder(owner, fields); problem != "" {
			return {}, problem
		}
	case "mesh":
		item.shape = .Mesh
		if item.files, item.scale, problem = parse_scene_mesh(owner, fields, configuration_names); problem != "" {
			return {}, problem
		}
	case:
		return {}, fmt.tprintf("%s: shape %s is neither box, cylinder, room nor mesh", owner, shape_name)
	}
	if item.position, problem = scene_vector_field(owner, "position", fields); problem != "" {
		return {}, problem
	}
	material_name: string
	if material_name, problem = scene_string_field(owner, "material", fields); problem != "" {
		return {}, problem
	}
	found: bool
	if item.material, found = material_id_by_name(library, material_name); !found {
		return {}, fmt.tprintf("%s: material %s not in the library", owner, material_name)
	}
	return item, ""
}

@(private = "file")
parse_scene_light :: proc(owner: string, value: json.Value) -> (light: Point_Light, problem: string) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("%s: expected an object", owner)
	}
	if problem = scene_check_keys(owner, fields, {"position", "colour", "intensity", "range"}); problem != "" {
		return {}, problem
	}
	if light.position, problem = scene_vector_field(owner, "position", fields); problem != "" {
		return {}, problem
	}
	if light.colour, problem = scene_vector_field(owner, "colour", fields); problem != "" {
		return {}, problem
	}
	if light.intensity, problem = scene_non_negative_field(owner, "intensity", fields); problem != "" {
		return {}, problem
	}
	if light.range, problem = scene_non_negative_field(owner, "range", fields); problem != "" {
		return {}, problem
	}
	return light, ""
}

// The text points into the parsed SJSON until parse_scene clones it.
@(private = "file")
parse_scene_label :: proc(owner: string, value: json.Value) -> (label: Scene_Label, problem: string) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("%s: expected an object", owner)
	}
	if problem = scene_check_keys(owner, fields, {"text", "position"}); problem != "" {
		return {}, problem
	}
	if label.text, problem = scene_string_field(owner, "text", fields); problem != "" {
		return {}, problem
	}
	if label.position, problem = scene_vector_field(owner, "position", fields); problem != "" {
		return {}, problem
	}
	return label, ""
}

@(private = "file")
parse_scene_box :: proc(owner: string, fields: json.Object) -> (size: [3]f32, problem: string) {
	if problem = scene_check_keys(owner, fields, {"shape", "size", "position", "material"}); problem != "" {
		return {}, problem
	}
	return scene_vector_field(owner, "size", fields)
}

@(private = "file")
parse_scene_cylinder :: proc(owner: string, fields: json.Object) -> (radius, height: f32, segments: int, problem: string) {
	if problem = scene_check_keys(owner, fields, {"shape", "radius", "height", "segments", "position", "material"}); problem != "" {
		return 0, 0, 0, problem
	}
	if radius, problem = scene_non_negative_field(owner, "radius", fields); problem != "" {
		return 0, 0, 0, problem
	}
	if height, problem = scene_non_negative_field(owner, "height", fields); problem != "" {
		return 0, 0, 0, problem
	}
	if segments, problem = scene_segments_field(owner, fields); problem != "" {
		return 0, 0, 0, problem
	}
	return radius, height, segments, ""
}

// The file names point into the parsed SJSON, in a slice of
// context.temp_allocator, until parse_scene clones them; scale is optional,
// above 0, 1 when absent.
@(private = "file")
parse_scene_mesh :: proc(owner: string, fields: json.Object, configuration_names: int) -> (files: []string, scale: f32, problem: string) {
	if problem = scene_check_keys(owner, fields, {"shape", "file", "files", "scale", "position", "material"}); problem != "" {
		return nil, 0, problem
	}
	if files, problem = parse_scene_mesh_files(owner, fields, configuration_names); problem != "" {
		return nil, 0, problem
	}
	if "scale" not_in fields do return files, 1, ""
	if scale, problem = scene_number_field(owner, "scale", fields); problem != "" {
		delete(files, context.temp_allocator)
		return nil, 0, problem
	}
	if scale <= 0 {
		delete(files, context.temp_allocator)
		return nil, 0, fmt.tprintf("%s: scale %v must be above 0", owner, scale)
	}
	return files, scale, ""
}

// One name from file, or one per configuration from files.
@(private = "file")
parse_scene_mesh_files :: proc(owner: string, fields: json.Object, configuration_names: int) -> (files: []string, problem: string) {
	has_file, has_files := "file" in fields, "files" in fields
	if has_file && has_files do return nil, fmt.tprintf("%s: file and files both given", owner)
	if !has_file && !has_files do return nil, fmt.tprintf("%s: file or files missing", owner)
	if has_file {
		file: string
		if file, problem = scene_string_field(owner, "file", fields); problem != "" {
			return nil, problem
		}
		files = make([]string, 1, context.temp_allocator)
		files[0] = file
		return files, ""
	}
	if files, problem = scene_string_array_field(owner, "files", fields); problem != "" {
		return nil, problem
	}
	// An empty files array is refused even when the scene names no configurations.
	if len(files) != configuration_names || len(files) == 0 {
		count := len(files)
		delete(files, context.temp_allocator)
		return nil, fmt.tprintf("%s: files has %d entries, the scene has %d configurations", owner, count, configuration_names)
	}
	return files, ""
}

@(private = "file")
scene_check_keys :: proc(owner: string, fields: json.Object, allowed: []string) -> (problem: string) {
	key_loop: for key in fields {
		for allowed_key in allowed {
			if key == allowed_key {
				continue key_loop
			}
		}
		return fmt.tprintf("%s: unknown key %s", owner, key)
	}
	return ""
}

@(private = "file")
scene_number_field :: proc(owner, key: string, fields: json.Object) -> (number: f32, problem: string) {
	value, present := fields[key]
	if !present {
		return 0, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_number: bool
	if number, is_number = json_number(value); !is_number {
		return 0, fmt.tprintf("%s: %s must be a number", owner, key)
	}
	return number, ""
}

@(private = "file")
scene_non_negative_field :: proc(owner, key: string, fields: json.Object) -> (number: f32, problem: string) {
	if number, problem = scene_number_field(owner, key, fields); problem != "" {
		return 0, problem
	}
	if number < 0 {
		return 0, fmt.tprintf("%s: %s %v must be 0 or more", owner, key, number)
	}
	return number, ""
}

// Three numbers.
@(private = "file")
scene_vector_field :: proc(owner, key: string, fields: json.Object) -> (vector: [3]f32, problem: string) {
	value, present := fields[key]
	if !present {
		return {}, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_vector: bool
	if vector, is_vector = json_vector(value); !is_vector {
		return {}, fmt.tprintf("%s: %s must be three numbers", owner, key)
	}
	return vector, ""
}

// The colour under the key, each component 0 or more, or the ambient level
// times white when the key is absent.
@(private = "file")
scene_hemisphere_colour :: proc(key: string, ambient: f32, fields: json.Object) -> (colour: [3]f32, problem: string) {
	if key not_in fields {
		return {ambient, ambient, ambient}, ""
	}
	if colour, problem = scene_vector_field("scene", key, fields); problem != "" {
		return {}, problem
	}
	if colour.x < 0 || colour.y < 0 || colour.z < 0 {
		return {}, fmt.tprintf("scene: %s %v must be 0 or more in each component", key, colour)
	}
	return colour, ""
}

@(private = "file")
scene_string_field :: proc(owner, key: string, fields: json.Object) -> (text: string, problem: string) {
	value, present := fields[key]
	if !present {
		return "", fmt.tprintf("%s: %s missing", owner, key)
	}
	is_string: bool
	if text, is_string = value.(json.String); !is_string {
		return "", fmt.tprintf("%s: %s must be a string", owner, key)
	}
	return text, ""
}

// An integer of at least 3.
@(private = "file")
scene_segments_field :: proc(owner: string, fields: json.Object) -> (segments: int, problem: string) {
	value, present := fields["segments"]
	if !present {
		return 0, fmt.tprintf("%s: segments missing", owner)
	}
	integer, is_integer := value.(json.Integer)
	if !is_integer || integer < 3 {
		return 0, fmt.tprintf("%s: segments must be an integer of at least 3", owner)
	}
	return int(integer), ""
}

@(private = "file")
scene_object_field :: proc(owner, key: string, fields: json.Object) -> (object: json.Object, problem: string) {
	value, present := fields[key]
	if !present {
		return nil, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_object: bool
	if object, is_object = value.(json.Object); !is_object {
		return nil, fmt.tprintf("%s: %s must be an object", owner, key)
	}
	return object, ""
}

@(private = "file")
scene_array_field :: proc(owner, key: string, fields: json.Object) -> (array: json.Array, problem: string) {
	value, present := fields[key]
	if !present {
		return nil, fmt.tprintf("%s: %s missing", owner, key)
	}
	is_array: bool
	if array, is_array = value.(json.Array); !is_array {
		return nil, fmt.tprintf("%s: %s must be an array", owner, key)
	}
	return array, ""
}
