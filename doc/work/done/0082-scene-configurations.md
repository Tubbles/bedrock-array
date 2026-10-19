# 0082: Scene configurations in the engine

Status: landed (2026-10-19, e20fde7)

Goal: a scene can name configurations (the hole closing techniques of 0081) and give a mesh item one blob per configuration; the view holds the current configuration, cycles it on an input edge, and draws each item's blob for it. The page (0083) and the app (0084) bind the cycle; the models scene (0085) uses it.

Verify:
- `./build.sh check` and `./build.sh test` pass with the new tests: `test_parse_scene_reads_configurations_and_files`, `test_parse_scene_rejects_files_of_the_wrong_count`, `test_scene_view_cycle_configuration`.
- `./build.sh web light` and `web models` build; the pages behave as before (no scene names configurations yet).

## Specification

- `src/engine/scene.odin`: `Scene.configurations: []string`, from the optional key `configurations` (an array of strings, cloned into the allocator, freed by `scene_destroy`); absent or empty means one unnamed configuration. `Scene_Item.file: string` becomes `files: []string`: the key `file` gives one entry, the key `files` an array whose length must equal `len(scene.configurations)` (else the problem `item N: files has X entries, the scene has Y configurations`); a mesh item needs one of the two (the existing problem text adapts), other shapes neither. `scene_item_mesh(item, meshes)` becomes `scene_item_mesh(item: Scene_Item, configuration: int, meshes) -> (Mesh_Data, problem)`, reading `item.files[min(configuration, len(item.files) - 1)]`, so an item with one file serves every configuration. `scene_configuration_count(scene) -> int` is `max(1, len(scene.configurations))`.
- `src/engine/scene_test.odin`: the two parse tests above (a scene text with `configurations = ["a", "b"]`, a mesh item with `files = ["x.mesh", "y.mesh"]` and one with `file = "z.mesh"`; the rejection with three files), the existing mesh item tests reading `files[0]`.
- `src/engine/scene_view.odin`: `Scene_View.configuration: int`; `Scene_Input.cycle_configuration: bool`, an edge the caller detects; `scene_view_step` cycles on it: `view.configuration = (view.configuration + 1) % scene_configuration_count(view.scene)`; `scene_view_configuration_name(view) -> string` (the name, or "" for a scene without configurations); `scene_view_configuration_count(view) -> int`. The uploads: `item_mesh_ids` and `item_half_extents` hold `len(items) * count` entries, index `item_index * count + configuration`; a blob file name is uploaded once and its `Mesh_Id` and half extents reused (a `map[string]int` of the upload index, temp allocated, since the base models share one file across every configuration and the full one is 36 MB); `scene_view_draw` reads the entry of the current configuration.
- `src/engine/scene_view_test.odin`: `test_scene_view_cycle_configuration`: a view whose scene has three configurations cycles 0, 1, 2, 0 through `scene_view_step` with the input's flag and reports the names; a view whose scene has none stays at 0 with the name "".
- `doc/render.md`: the scene files paragraph names `configurations` and `files` and what an item with one `file` does under them; the view sentence names the configuration index and the cycle on the input's edge.
