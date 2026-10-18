# 0014: Scene files

Status: landed (2026-10-18, 4fe6c8e)

Goal: a demo's scene is data, `data/demos/<name>/scene.sjson`, parsed by the engine into a `Scene` the demo turns into meshes, lights and a draw list, so the cave and surface scenes of D1 are edited as text (CLAUDE.md: never hardcode content in Odin) and later from the in game editor. This item is the format and the parser; 0015 moves the light demo onto it.

Verify:
- `./build.sh check`, `./build.sh test` (twenty tests: three new).

## Specification (main agent, 2026-10-18)

The format, SJSON, every key required unless noted, unknown keys are errors (the strictness rule of `parse_material_library`):

```
camera = { target = [0, 0.5, 0], yaw = 0.6, pitch = 0.5, distance = 5 }
sun = { direction = [0.4, -1, -0.3], colour = [1, 0.96, 0.9], intensity = 1 }
exposure = 1
items = [
	{ shape = "box", size = [1, 1, 1], position = [0, 0.5, 0], material = "painted_steel" }
	{ shape = "cylinder", radius = 0.5, height = 1, segments = 24, position = [1.5, 0.5, 0], material = "copper" }
]
lights = [
	{ position = [-1.5, 0.3, 1.5], colour = [1, 0.6, 0.3], intensity = 2, range = 4 }
]
```

- `src/engine/material.odin`: `material_number` becomes the package level `json_number` (same body, the NaN and infinity rejection kept), used by both parsers.
- `src/engine/scene.odin`: `Scene_Shape :: enum { Box, Cylinder }`; `Scene_Item :: struct { shape: Scene_Shape, size: [3]f32, radius, height: f32, segments: int, position: [3]f32, material: Material_Id }` (`size` for a box, `radius`, `height`, `segments` for a cylinder, the other keys an error for that shape); `Scene :: struct { camera: Orbit, sun: Directional_Light, exposure: f32, items: []Scene_Item, lights: []Point_Light }`; `parse_scene(data: []byte, library: Material_Library, allocator := context.allocator) -> (scene: Scene, problem: string)` with the same allocation pattern as `parse_material_library` (temp allocator during the walk, the result in `allocator`, `json.destroy_value` deferred, the problem text in the temp allocator naming the key and the item index, for example `item 1: material unknown_name not in the library`); `scene_destroy`. Readers as small file private procedures: `scene_number_field`, `scene_vector_field` (three numbers), `scene_string_field`; `segments` must be an integer of at least 3, `distance`, `range`, `intensity`, `exposure` at least 0, `direction` not all zero. `lights` and `items` may be empty arrays, `lights` may be absent.
- `src/engine/scene_test.odin` (`#+build !js`): `test_parse_scene_reads_the_example` (the example above against a library parsed from an inline two material SJSON string: two items, one light, the cylinder's segments 24, the second item's material id equals `material_id_by_name(library, "copper")`), `test_parse_scene_rejects_an_unknown_material`, `test_parse_scene_rejects_an_unknown_key` (a `colour` key on a box item).
- `doc/render.md`: a new section `## Scene files` after Materials: the format in one paragraph, where the files live, and that a demo turns a `Scene` into its meshes and draw list.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty tests), `./build.sh web light`.
