# 0016: The scene page in the engine

Status: landed (2026-10-18, 46fd209)

Goal: what the light demo settled (the canvas, the resize, the orbit input, the scene upload and the draw) moves into the engine as `Scene_Page`, so the cave and surface pages that follow are a scene file and a dozen lines of Odin each, and the pointer and orbit code exists once. The light page behaves exactly as before. Builds on 0015.

Verify:
- `./build.sh check`, `./build.sh test` (twenty one tests), `./build.sh web light`; the page looks and orbits as before (the user).

## Specification (main agent, 2026-10-18)

Fact read 2026-10-18 from `~/opt/odin/core/sys/wasm/js/events.odin`: `js.Event` carries `user_data: rawptr`, the pointer given to `add_event_listener`, so a handler reaches its page through `(^Scene_Page)(event.user_data)`.

- `src/engine/web_scene_page.odin` (`#+build js wasm32`): `Scene_Page :: struct { renderer: Webgl_Renderer, library: Material_Library, scene: Scene, item_mesh_ids: []Mesh_Id, draw_list: Draw_List, orbit: Orbit, canvas_width, canvas_height: i32, active_pointers: [2]Scene_Page_Pointer, active_pointer_count: int, ready: bool }` with `Scene_Page_Pointer` and the constants of the demo moved over as `SCENE_PAGE_DRAG_RADIANS_PER_PIXEL`, `SCENE_PAGE_WHEEL_ZOOM_STEP`, `SCENE_PAGE_DISTANCE_MINIMUM`, `SCENE_PAGE_DISTANCE_MAXIMUM`. `scene_page_init(page: ^Scene_Page, canvas_id: string, library_data, scene_data: []byte) -> (problem: string)`: the WebGL2 context by `canvas_id`, the resize, the window resize listener and the five canvas listeners with `page` as user data, the library and the scene parsed (the problem returned with a `material library: ` or `scene: ` prefix), the renderer initialised (`"the WebGL2 shaders did not compile"` as the problem), one mesh per item uploaded through `scene_item_mesh`, `orbit` from `scene.camera`. `scene_page_step(page: ^Scene_Page)`: nothing until `ready`, then the draw list from the scene and the orbit, the draw. The handlers and the pointer helpers move over unchanged in behaviour, taking the page from the event's user data; the resize reads the canvas id stored in the page (`canvas_id: string` field). All file private except the type, the constants, `scene_page_init` and `scene_page_step`.
- `src/demos/light/main.odin` shrinks to: the package global `page: engine.Scene_Page`, `main` calling `scene_page_init(&page, "canvas", #load(library), #load(scene))` and printing a non empty problem with `fmt.eprintln`, `step` calling `scene_page_step(&page)` and returning true. Nothing else stays.
- `doc/build.md`, Writing a demo: the paragraph says a scene demo is `Scene_Page` plus its scene file, with the input it brings (drag, pinch, wheel). `doc/render.md`, Scene files: one sentence that `Scene_Page` (web only) draws a scene on a canvas with the orbit input, replacing the demo level clause at its end.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty one tests), `./build.sh web light`.
