#+build !js
package engine

import "core:strings"
import "core:testing"

@(test)
test_texture_set_decodes_the_shipped_painted_steel :: proc(t: ^testing.T) {
	files := #load_directory("../../data/materials/textures")
	set, problem := texture_set_from_files(files, "painted_steel")
	defer texture_set_data_destroy(&set)
	testing.expect_value(t, problem, "")
	for image in ([3]Image_Data{set.albedo, set.normal, set.surface}) {
		testing.expect_value(t, image.width, 512)
		testing.expect_value(t, image.height, 512)
		testing.expect_value(t, len(image.pixels), 512 * 512 * 4)
	}
}

@(test)
test_texture_set_names_a_missing_file :: proc(t: ^testing.T) {
	files := #load_directory("../../data/materials/textures")
	set, problem := texture_set_from_files(files, "nothing")
	defer texture_set_data_destroy(&set)
	testing.expectf(t, strings.contains(problem, "nothing_albedo.png missing"), "problem: %q", problem)
}
