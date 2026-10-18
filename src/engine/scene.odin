package engine

import "core:encoding/json"
import "core:fmt"

Scene_Shape :: enum {
	Box,
	Cylinder,
}

// size for a box, radius, height and segments for a cylinder.
Scene_Item :: struct {
	shape:          Scene_Shape,
	size:           [3]f32,
	radius, height: f32,
	segments:       int,
	position:       [3]f32,
	material:       Material_Id,
}

Scene :: struct {
	camera:   Orbit,
	sun:      Directional_Light,
	exposure: f32,
	items:    []Scene_Item,
	lights:   []Point_Light,
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
		case "camera", "sun", "exposure", "items", "lights":
		case:
			return {}, fmt.tprintf("scene: unknown key %s", key)
		}
	}
	if scene.camera, problem = parse_scene_camera(fields); problem != "" {
		return {}, problem
	}
	if scene.sun, problem = parse_scene_sun(fields); problem != "" {
		return {}, problem
	}
	if scene.exposure, problem = scene_non_negative_field("scene", "exposure", fields); problem != "" {
		return {}, problem
	}
	items_array, items_problem := scene_array_field("scene", "items", fields)
	if items_problem != "" {
		return {}, items_problem
	}
	items := make([]Scene_Item, len(items_array), context.temp_allocator)
	defer delete(items, context.temp_allocator)
	for element, index in items_array {
		if items[index], problem = parse_scene_item(fmt.tprintf("item %d", index), element, library); problem != "" {
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
	scene.items = make([]Scene_Item, len(items), allocator)
	copy(scene.items, items)
	scene.lights = make([]Point_Light, len(lights), allocator)
	copy(scene.lights, lights)
	return scene, ""
}

scene_destroy :: proc(scene: ^Scene, allocator := context.allocator) {
	delete(scene.items, allocator)
	delete(scene.lights, allocator)
	scene.items = nil
	scene.lights = nil
}

@(private = "file")
parse_scene_camera :: proc(fields: json.Object) -> (camera: Orbit, problem: string) {
	camera_fields: json.Object
	if camera_fields, problem = scene_object_field("scene", "camera", fields); problem != "" {
		return {}, problem
	}
	if problem = scene_check_keys("camera", camera_fields, {"target", "yaw", "pitch", "distance"}); problem != "" {
		return {}, problem
	}
	if camera.target, problem = scene_vector_field("camera", "target", camera_fields); problem != "" {
		return {}, problem
	}
	if camera.yaw, problem = scene_number_field("camera", "yaw", camera_fields); problem != "" {
		return {}, problem
	}
	if camera.pitch, problem = scene_number_field("camera", "pitch", camera_fields); problem != "" {
		return {}, problem
	}
	if camera.distance, problem = scene_non_negative_field("camera", "distance", camera_fields); problem != "" {
		return {}, problem
	}
	return camera, ""
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
parse_scene_item :: proc(owner: string, value: json.Value, library: Material_Library) -> (item: Scene_Item, problem: string) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("%s: expected an object", owner)
	}
	shape_name: string
	if shape_name, problem = scene_string_field(owner, "shape", fields); problem != "" {
		return {}, problem
	}
	switch shape_name {
	case "box":
		item.shape = .Box
		if item.size, problem = parse_scene_box(owner, fields); problem != "" {
			return {}, problem
		}
	case "cylinder":
		item.shape = .Cylinder
		if item.radius, item.height, item.segments, problem = parse_scene_cylinder(owner, fields); problem != "" {
			return {}, problem
		}
	case:
		return {}, fmt.tprintf("%s: shape %s is neither box nor cylinder", owner, shape_name)
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
