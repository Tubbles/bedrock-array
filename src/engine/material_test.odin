#+build !js
package engine

import "core:strings"
import "core:testing"

@(test)
test_material_library_parses_the_shipped_file :: proc(t: ^testing.T) {
	library, problem := parse_material_library(#load("../../data/materials/library.sjson"))
	defer material_library_destroy(&library)
	testing.expect_value(t, problem, "")
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
test_material_library_rejects_a_zero_edge_width :: proc(t: ^testing.T) {
	text := `steel = {albedo = [0.5, 0.5, 0.5], roughness = 0.5, metallic = 0, textures = "x", wear = {edge_width = 0, chip_threshold = 0.5, amount = 0.5, metal = [0.5, 0.5, 0.5]}}`
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "edge_width must be above 0"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}

@(test)
test_material_library_rejects_textures_without_wear :: proc(t: ^testing.T) {
	text := `steel = {albedo = [0.5, 0.5, 0.5], roughness = 0.5, metallic = 0, textures = "x"}`
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "textures without wear"), "problem: %q", problem)
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

	wear_text := "glass = {albedo = [0.9, 0.95, 1], roughness = 0.05, metallic = 0, wear = {edge_width = 1e300, chip_threshold = 0.5, amount = 0, metal = [0.5, 0.5, 0.5]}}"
	wear_library, wear_problem := parse_material_library(transmute([]byte)wear_text)
	defer material_library_destroy(&wear_library)
	testing.expectf(t, strings.contains(wear_problem, "edge_width must be a number"), "problem: %q", wear_problem)

	emissive_text := "glass = {albedo = [0.9, 0.95, 1], roughness = 0.05, metallic = 0, emissive = [Infinity, 0, 0]}"
	emissive_library, emissive_problem := parse_material_library(transmute([]byte)emissive_text)
	defer material_library_destroy(&emissive_library)
	testing.expectf(t, strings.contains(emissive_problem, "emissive"), "problem: %q", emissive_problem)
}

@(test)
test_material_library_reads_textures_and_wear :: proc(t: ^testing.T) {
	library, problem := parse_material_library(#load("../../data/materials/library.sjson"))
	defer material_library_destroy(&library)
	testing.expect_value(t, problem, "")
	painted_steel, painted_steel_found := material_id_by_name(library, "painted_steel")
	testing.expect(t, painted_steel_found)
	if painted_steel_found {
		material := library.materials[painted_steel]
		testing.expect_value(t, material.textures, "painted_steel")
		testing.expect_value(t, material.wear.chip_threshold, 0.85)
		testing.expect_value(t, material.wear.metal.b, 0.58)
	}
	copper, copper_found := material_id_by_name(library, "copper")
	testing.expect(t, copper_found)
	if copper_found {
		testing.expect_value(t, library.materials[copper].textures, "")
	}
}

@(test)
test_material_library_rejects_a_wear_with_an_unknown_key :: proc(t: ^testing.T) {
	text := "painted_steel = {albedo = [0.2, 0.24, 0.3], roughness = 0.55, metallic = 0, wear = {edge_width = 0.05, chip_threshold = 0.85, amount = 0.5, metal = [0.56, 0.57, 0.58], depth = 1}}"
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "wear: unknown key depth"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}

@(test)
test_material_library_rejects_a_textures_that_is_not_a_string :: proc(t: ^testing.T) {
	text := "painted_steel = {albedo = [0.2, 0.24, 0.3], roughness = 0.55, metallic = 0, textures = 3}"
	library, problem := parse_material_library(transmute([]byte)text)
	defer material_library_destroy(&library)
	testing.expectf(t, strings.contains(problem, "textures must be a string"), "problem: %q", problem)
	testing.expect_value(t, len(library.materials), 0)
}
