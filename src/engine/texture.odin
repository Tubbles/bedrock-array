package engine

import "base:runtime"
import "core:fmt"
import "core:image/png"
import "core:slice"

// RGBA, 8 bit, top row first as the PNG holds it.
Image_Data :: struct {
	width, height: int,
	pixels:        []byte,
}

// The three images of a texture set (doc/workflows/materials.md).
Texture_Set_Data :: struct {
	albedo, normal, surface: Image_Data,
}

// Decodes <name>_albedo.png, <name>_normal.png and <name>_surface.png from files.
// The problem text lives in context.temp_allocator, valid until its next reset.
texture_set_from_files :: proc(files: []runtime.Load_Directory_File, name: string, allocator := context.allocator) -> (set: Texture_Set_Data, problem: string) {
	images: [3]Image_Data
	for suffix, index in ([3]string{"albedo", "normal", "surface"}) {
		images[index], problem = texture_image_from_files(files, name, suffix, allocator)
		if problem != "" {
			for image in images[:index] do delete(image.pixels, allocator)
			return {}, problem
		}
	}
	return Texture_Set_Data{albedo = images[0], normal = images[1], surface = images[2]}, ""
}

texture_set_data_destroy :: proc(set: ^Texture_Set_Data, allocator := context.allocator) {
	delete(set.albedo.pixels, allocator)
	delete(set.normal.pixels, allocator)
	delete(set.surface.pixels, allocator)
	set^ = {}
}

@(private = "file")
texture_image_from_files :: proc(files: []runtime.Load_Directory_File, name, suffix: string, allocator := context.allocator) -> (image: Image_Data, problem: string) {
	file_name := fmt.tprintf("%s_%s.png", name, suffix)
	data, found := texture_file_find(files, file_name)
	if !found do return {}, fmt.tprintf("texture set %s: %s missing", name, file_name)
	return texture_image_decode(data, name, file_name, allocator)
}

@(private = "file")
texture_file_find :: proc(files: []runtime.Load_Directory_File, file_name: string) -> (data: []byte, found: bool) {
	for file in files {
		if file.name == file_name do return file.data, true
	}
	return nil, false
}

// png.destroy frees the image and its metadata with context.allocator, not the allocator it loaded with.
@(private = "file")
texture_png_destroy :: proc(decoded: ^png.Image) {
	context.allocator = context.temp_allocator
	png.destroy(decoded)
}

@(private = "file")
texture_image_decode :: proc(data: []byte, name, file_name: string, allocator := context.allocator) -> (image: Image_Data, problem: string) {
	decoded, error := png.load_from_bytes(data, {.alpha_add_if_missing}, context.temp_allocator)
	if error != nil do return {}, fmt.tprintf("texture set %s: %s: %v", name, file_name, error)
	defer texture_png_destroy(decoded)
	if decoded.depth != 8 || decoded.channels != 4 {
		return {}, fmt.tprintf("texture set %s: %s is not 8 bit RGBA", name, file_name)
	}
	pixels := slice.clone(decoded.pixels.buf[:], allocator)
	return Image_Data{width = decoded.width, height = decoded.height, pixels = pixels}, ""
}
