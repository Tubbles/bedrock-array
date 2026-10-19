# 0083: The configuration button on the page

Status: landed (2026-10-19, 4a23c42)

Goal: on a page whose scene names configurations, an on screen button shows the current one and cycles it on a tap or click, and so do the C key and the gamepad's North button (user, 2026-10-19: "some virtual on screen button, or bound to a button on the gamepad"). Follows 0082.

Verify:
- `./build.sh check`, `test`, `web light` and `web models` pass; a page without configurations shows no button (the reviewer reads the JS and the exports).
- The exports `configuration_count`, `configuration_name_pointer`, `configuration_name_length` and `cycle_configuration` exist on the page and the C key and the pad's North button set the input's edge once per press (the reviewer traces a frame).

## Specification

- `src/engine/web_scene_page.odin`: `Scene_Page.cycle_pending: bool` and `north_held: bool`; `on_scene_page_key_down` sets `cycle_pending` for the code `KeyC` (not a repeat) before the walk keys are looked up; `scene_page_gamepad` reads `state.buttons[3].pressed` (North in the standard mapping) and sets `cycle_pending` on the frame it becomes pressed, keeping `north_held`; `scene_page_step` moves `cycle_pending` into `input.cycle_configuration` and clears it. Four contextless exports beside the label ones: `configuration_count() -> i32`, `configuration_name_pointer() -> rawptr`, `configuration_name_length() -> i32` (the current name), `cycle_configuration()` (calls `scene_view_cycle_configuration`, so the button does not wait for a frame), all on the registered page, 0 or nil without one.
- `web/configuration.js` (the shape of `labels.js`, its own memory interface is not needed: it reads `odin` through the same `memory.exports` by sharing the interface, so `labels.js` exposes it on `window.bedrockMemory`, or the two files merge their frame loops into one file; the implementer picks the smaller change and says which): when `configuration_count() > 1`, one `<button class="configuration">` appended to the body with the current name as its text, refreshed each frame when it changes, `click` calling `cycle_configuration()` and refreshing. `web/index.html` loads it after `labels.js`. `web/style.css`: `.configuration` fixed at the bottom left above the back link, the label's colours and font at 1rem, at least 44 px tall, `touch-action: manipulation`, no outline on focus.
- `doc/render.md`: the page's input sentence adds the C key, the North button and the on screen button for the configuration.
