# 0089: Orbit input on the page

Status: landed (2026-10-19, f40690c)

Goal: a page whose scene orbits (0088) turns by a drag, zooms by the wheel and a pinch, and steps the configuration both ways by the arrows, the pad's shoulders and two page buttons.

Verify:
- `./build.sh test`, `./build.sh check`, `./build.sh web light`, `./build.sh web models`.

## Specification

- `src/engine/scene_touch.odin`: `touch_pair_spread :: proc(previous, current: [2][2]f32) -> f32` (the change of the fingers' distance in pixels), used by `touch_pair_move`. Test `test_touch_pair_spread` in `scene_touch_test.odin`.
- `src/engine/web_scene_page.odin`: `SCENE_PAGE_PINCH_ZOOM_PER_PIXEL :: f32(0.005)`, `SCENE_PAGE_WHEEL_ZOOM_PER_PIXEL :: f32(0.001)`; `Scene_Page` gains `zoom_pending: f32`, `previous_pending: bool`, `shoulders_held: [2]bool`, handed to the input and cleared in `scene_page_step`. When `page.view.scene.camera_mode == .Orbit`: a mouse move turns only while a button is down (`event.data.mouse.buttons != {}`, the client still stored), a finger turns by the plain movement times `SCENE_PAGE_DRAG_RADIANS_PER_PIXEL` (it grabs the model, so no `touch_turn`), two fingers add `touch_pair_spread * SCENE_PAGE_PINCH_ZOOM_PER_PIXEL` to `zoom_pending` instead of a move, and a key down of `ArrowLeft` sets `previous_pending` and `ArrowRight` sets `cycle_pending` without either entering `keys_held`. A `Wheel` listener on the canvas adds `-delta.y * SCENE_PAGE_WHEEL_ZOOM_PER_PIXEL` in either mode (fly ignores zoom). In both modes the pad's left shoulder (button 4) edge sets `previous_pending` and the right (5) `cycle_pending`, like North.
- Export `previous_configuration` beside `cycle_configuration`. `web/labels.js`: with more than one configuration, a `◀` button calling it left of the name button and a `▶` button calling `cycle_configuration` right of it, each refreshing and blurring like the name button; `web/style.css` places the three in a row at the bottom left (a `.configurations` flex container holding the buttons).
- `doc/render.md` (page input sentence and exports) and the four `src/demos/*/description.txt` stay true; the models description adds the shoulders and the arrow buttons.
