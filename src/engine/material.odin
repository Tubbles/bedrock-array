package engine

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"

Material :: struct {
	name:                string,
	albedo:              [3]f32,
	roughness, metallic: f32,
	emissive:            [3]f32,
	textures:            string,
	wear:                Material_Wear,
}

// The wear rule of doc/workflows/materials.md, zeros when the preset has none.
Material_Wear :: struct {
	edge_width, chip_threshold, amount: f32,
	metal:                              [3]f32,
}

// Indexed by Material_Id: the materials in alphabetical order of name.
Material_Library :: struct {
	materials: []Material,
}

// Parses data/materials/library.sjson. The problem names the material
// and the key, and is empty when all is well.
// The problem text lives in context.temp_allocator, valid until its next reset.
parse_material_library :: proc(data: []byte, allocator := context.allocator) -> (library: Material_Library, problem: string) {
	value, error := json.parse(data, .SJSON, true, context.temp_allocator)
	defer json.destroy_value(value, context.temp_allocator)
	if error != nil {
		return {}, fmt.tprintf("not SJSON: %v", error)
	}
	object, is_object := value.(json.Object)
	if !is_object {
		return {}, "expected one object per material"
	}
	names := material_names_sorted(object)
	defer delete(names, context.temp_allocator)
	materials := make([]Material, len(names), context.temp_allocator)
	defer delete(materials, context.temp_allocator)
	for name, index in names {
		materials[index], problem = parse_material(name, object[name])
		if problem != "" {
			return {}, problem
		}
	}
	library.materials = make([]Material, len(materials), allocator)
	for material, index in materials {
		library.materials[index] = material
		library.materials[index].name = strings.clone(material.name, allocator)
		library.materials[index].textures = strings.clone(material.textures, allocator)
	}
	return library, ""
}

material_library_destroy :: proc(library: ^Material_Library, allocator := context.allocator) {
	for material in library.materials {
		delete(material.name, allocator)
		delete(material.textures, allocator)
	}
	delete(library.materials, allocator)
	library.materials = nil
}

material_id_by_name :: proc(library: Material_Library, name: string) -> (Material_Id, bool) {
	for material, index in library.materials {
		if material.name == name {
			return Material_Id(index), true
		}
	}
	return 0, false
}

// json.Object is a map, so the sorted names give deterministic ids.
@(private = "file")
material_names_sorted :: proc(object: json.Object) -> []string {
	names := make([dynamic]string, 0, len(object), context.temp_allocator)
	for name in object {
		append(&names, name)
	}
	slice.sort(names[:])
	return names[:]
}

@(private = "file")
parse_material :: proc(name: string, value: json.Value) -> (material: Material, problem: string) {
	fields, is_object := value.(json.Object)
	if !is_object {
		return {}, fmt.tprintf("material %s: expected an object", name)
	}
	for key in fields {
		switch key {
		case "albedo", "roughness", "metallic", "emissive", "textures", "wear":
		case:
			return {}, fmt.tprintf("material %s: unknown key %s", name, key)
		}
	}
	material.name = name
	if material.albedo, problem = material_colour_field(name, "albedo", fields, true); problem != "" {
		return {}, problem
	}
	if material.roughness, problem = material_number_field(name, "roughness", fields, true); problem != "" {
		return {}, problem
	}
	if material.metallic, problem = material_number_field(name, "metallic", fields, true); problem != "" {
		return {}, problem
	}
	if "emissive" in fields {
		if material.emissive, problem = material_colour_field(name, "emissive", fields, false); problem != "" {
			return {}, problem
		}
	}
	if textures, present := fields["textures"]; present {
		is_string: bool
		if material.textures, is_string = textures.(json.String); !is_string {
			return {}, fmt.tprintf("material %s: textures must be a string", name)
		}
	}
	if "wear" in fields {
		if material.wear, problem = material_wear_field(name, fields); problem != "" {
			return {}, problem
		}
	}
	return material, ""
}

// The wear object's problems read "material <name>: wear: <key> ...".
@(private = "file")
material_wear_field :: proc(name: string, fields: json.Object) -> (wear: Material_Wear, problem: string) {
	wear_fields, is_object := fields["wear"].(json.Object)
	if !is_object {
		return {}, fmt.tprintf("material %s: wear must be an object", name)
	}
	for key in wear_fields {
		switch key {
		case "edge_width", "chip_threshold", "amount", "metal":
		case:
			return {}, fmt.tprintf("material %s: wear: unknown key %s", name, key)
		}
	}
	prefix := fmt.tprintf("%s: wear", name)
	if wear.edge_width, problem = material_number_field(prefix, "edge_width", wear_fields, false); problem != "" {
		return {}, problem
	}
	if wear.chip_threshold, problem = material_number_field(prefix, "chip_threshold", wear_fields, true); problem != "" {
		return {}, problem
	}
	if wear.amount, problem = material_number_field(prefix, "amount", wear_fields, false); problem != "" {
		return {}, problem
	}
	if wear.metal, problem = material_colour_field(prefix, "metal", wear_fields, true); problem != "" {
		return {}, problem
	}
	return wear, ""
}

// A number 0 to 1, or 0 or more when at_most_one is false.
@(private = "file")
material_number_field :: proc(name, key: string, fields: json.Object, at_most_one: bool) -> (number: f32, problem: string) {
	value, present := fields[key]
	if !present {
		return 0, fmt.tprintf("material %s: %s missing", name, key)
	}
	is_number: bool
	if number, is_number = json_number(value); !is_number {
		return 0, fmt.tprintf("material %s: %s must be a number", name, key)
	}
	if number < 0 || (at_most_one && number > 1) {
		return 0, fmt.tprintf("material %s: %s %v is outside %s", name, key, number, at_most_one ? "0 to 1" : "0 or more")
	}
	return number, ""
}

// Three numbers, each 0 to 1, or 0 or more when at_most_one is false.
@(private = "file")
material_colour_field :: proc(name, key: string, fields: json.Object, at_most_one: bool) -> (colour: [3]f32, problem: string) {
	value, present := fields[key]
	if !present {
		return {}, fmt.tprintf("material %s: %s missing", name, key)
	}
	is_colour: bool
	if colour, is_colour = json_vector(value); !is_colour {
		return {}, fmt.tprintf("material %s: %s must be three numbers", name, key)
	}
	for component in colour {
		if component < 0 || (at_most_one && component > 1) {
			return {}, fmt.tprintf("material %s: %s %v is outside %s", name, key, colour, at_most_one ? "0 to 1" : "0 or more")
		}
	}
	return colour, ""
}

json_number :: proc(value: json.Value) -> (f32, bool) {
	#partial switch number in value {
	case json.Float:
		// The cast to f32 overflows a large finite f64 to infinity, so the check follows it.
		narrowed := f32(number)
		if math.is_nan(narrowed) || math.is_inf(narrowed) {
			return 0, false
		}
		return narrowed, true
	case json.Integer:
		return f32(number), true
	}
	return 0, false
}

json_vector :: proc(value: json.Value) -> (colour: [3]f32, is_colour: bool) {
	array, is_array := value.(json.Array)
	if !is_array || len(array) != 3 {
		return {}, false
	}
	for element, index in array {
		colour[index] = json_number(element) or_return
	}
	return colour, true
}
