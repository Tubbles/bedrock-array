# 0031: The texture set and wear keys of the library

Status: designed (2026-10-18)

Goal: a preset of `data/materials/library.sjson` can name its texture set and its wear rule (`doc/workflows/materials.md`, Files), read by the Odin parser with the library's strictness, so the renderer items that follow (upload, triplanar sampling, the wear rule) have the data. Refers to item 0028.

Verify:
- `./build.sh test` passes with the three new tests.

## Specification (main agent, 2026-10-18)

- `src/engine/material.odin`: `Material` gains `textures: string` (the set's name, empty when the preset has none) and `wear: Material_Wear`, a new struct `{ edge_width, chip_threshold, amount: f32 }`, zeros when absent. `parse_material` accepts the keys `textures` and `wear` beside the four it has. `textures` must be a `json.String`, else the problem `material %s: textures must be a string`; it is cloned into the library's allocator in `parse_material_library` beside the name and freed in `material_library_destroy`. `wear` must be an object with exactly the keys `edge_width` (a number, 0 or more, metres), `chip_threshold` (0 to 1) and `amount` (0 or more), read by a new file private `material_wear_field(name, fields) -> (Material_Wear, problem)`; an unknown key inside it gives `material %s: wear: unknown key %s`, a missing one `material %s: wear: %s missing`, a range problem names the key as `material_unit_field` does. Reuse `json_number`. Short procedures.
- `data/materials/library.sjson`: `painted_steel` gains `textures = "painted_steel"` and `wear = { edge_width = 0.05 chip_threshold = 0.85 amount = 0.5 }` (one member per line inside, as the file's objects are written). No other preset changes.
- `src/engine/material_test.odin`: `test_material_library_reads_textures_and_wear` (the shipped file: `painted_steel` has `textures == "painted_steel"` and `wear.chip_threshold == 0.85`, `copper` has an empty `textures`), `test_material_library_rejects_a_wear_with_an_unknown_key` (`wear = { edge_width = 0.05, chip_threshold = 0.85, amount = 0.5, depth = 1 }`, problem contains `wear: unknown key depth`), `test_material_library_rejects_a_textures_that_is_not_a_string` (`textures = 3`, problem contains `textures must be a string`).
- `doc/render.md`, the library sentence of the Scene files section (line 19): the two optional keys added after `emissive`, in the same style: `textures` (a string, the texture set of `doc/workflows/materials.md`) and `wear` (`edge_width` in metres, `chip_threshold` 0 to 1, `amount`, the wear rule of the same document).

Verify: `./build.sh check`, `./build.sh test` (thirty two tests).
