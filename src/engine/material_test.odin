#+build !js
package engine

import "core:strings"
import "core:testing"

@(test)
test_material_library_parses_the_shipped_file :: proc(t: ^testing.T) {
	library, problem := parse_material_library(#load("../../data/materials/library.sjson"))
	defer material_library_destroy(&library)
	testing.expect_value(t, problem, "")
	testing.expect_value(t, len(library.materials), 6)
	copper, found := material_id_by_name(library, "copper")
	testing.expect(t, found)
	if found {
		testing.expect_value(t, library.materials[copper].metallic, 1)
	}
	bare_alloy, bare_alloy_found := material_id_by_name(library, "bare_alloy")
	testing.expect(t, bare_alloy_found)
	testing.expect_value(t, bare_alloy, 0)
}

@(test)
test_material_library_rejects_an_unknown_key :: proc(t: ^testing.T) {
	text := "copper = {albedo = [0.95, 0.64, 0.54], roughness = 0.3, metallic = 1, shine = 1}"
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "unknown key shine"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}

@(test)
test_material_library_rejects_a_roughness_out_of_range :: proc(t: ^testing.T) {
	text := "glass = {albedo = [0.9, 0.95, 1], roughness = 1.5, metallic = 0}"
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "roughness"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}

@(test)
test_material_library_rejects_a_missing_albedo :: proc(t: ^testing.T) {
	text := "rubber = {roughness = 0.9, metallic = 0}"
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "albedo missing"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}

@(test)
test_material_library_rejects_a_non_finite_number :: proc(t: ^testing.T) {
	roughness_text := "glass = {albedo = [0.9, 0.95, 1], roughness = NaN, metallic = 0}"
	roughness_library, roughness_problem := parse_material_library(transmute([]byte)roughness_text)
	defer material_library_destroy(&roughness_library)
	testing.expectf(t, strings.contains(roughness_problem, "roughness"), "problem: %q", roughness_problem)

	emissive_text := "glass = {albedo = [0.9, 0.95, 1], roughness = 0.05, metallic = 0, emissive = [Infinity, 0, 0]}"
	emissive_library, emissive_problem := parse_material_library(transmute([]byte)emissive_text)
	defer material_library_destroy(&emissive_library)
	testing.expectf(t, strings.contains(emissive_problem, "emissive"), "problem: %q", emissive_problem)
}
