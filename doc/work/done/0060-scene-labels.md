# 0060: Scene labels

Status: landed (2026-10-19, 094315f)

Goal: a scene names what stands in it with a plaque the reader can read on the phone (user, 2026-10-19: "with plaques so I know which is which"). The engine's runtime has no DOM writer, so the labels are HTML elements the page's small JS glue moves to the projected screen positions each frame, and the text stays crisp at any zoom.

Verify:
- `./build.sh test` passes with `test_world_to_screen_centre_and_behind` (a point on the camera's axis projects to the canvas centre, a point above it lands higher, a point behind the camera is not visible) and `test_parse_scene_reads_labels` (a `labels = [{ text = "full", position = [0, 1.2, 0] }]` parses, an item without `text` is rejected).
- `./build.sh web light` builds and the page carries `labels.js`; the label count export reads 0 for the light demo.

## Specification

- `src/engine/scene.odin`: `Scene_Label :: struct { text: string, position: [3]f32 }`, `Scene` gains `labels: []Scene_Label` from the optional `labels` array (`text` and `position` required, the unknown key rule as for items), freed in `scene_destroy`.
- `src/engine/render_camera.odin`: `world_to_screen(camera: Camera, aspect: f32, canvas: [2]f32, world: [3]f32) -> (pixel: [2]f32, visible: bool)`: the clip space position through `projection_matrix(camera, aspect) * view_matrix(camera)`, visible when w is positive and the normalised x and y lie within minus one to one, the pixel from the top left with y down.
- `src/engine/web_scene_page.odin`: the page keeps `page.aspect` and the canvas size it has; four exported procs, `"contextless"`, reading the one page instance the demo registers through `scene_page_register(page: ^Scene_Page)` (a file level pointer, set in `scene_page_init`): `label_count() -> i32`, `label_text_pointer(index: i32) -> rawptr`, `label_text_length(index: i32) -> i32`, `label_screen_x(index: i32) -> f32`, `label_screen_y(index: i32) -> f32`, `label_visible(index: i32) -> bool`, the screen values in CSS pixels (the canvas size over the device pixel ratio the page already tracks for the client height) from `world_to_screen` with the current orbit's camera.
- `web/labels.js`: builds `new odin.WasmMemoryInterface()`, passes it to `odin.runWasm("demo.wasm", null, undefined, memory)` in place of the bare call in `index.html`, then, once that resolves (the runtime has registered the demo's step by then, so the plaques are placed after it), each animation frame reads the exports: creates one `<div class="label">` per label on the first frame with its text from `memory.loadString(pointer, length)`, and sets each div's `left`, `top` (translated to centre the div above the point) and `visibility` from the three exports. `web/style.css`: `.label` as a small dark rounded box with light sans serif text, `pointer-events: none`, `position: fixed`, `transform: translate(-50%, -100%)`. `build.sh`'s `build_web` copies `labels.js`; `web/index.html` loads it after `odin.js` and no longer calls `runWasm` itself.
- `doc/render.md`, Scene files: the `labels` key; `doc/build.md`: the page shell's `labels.js` in one clause.
