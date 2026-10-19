# 0063: Space and Control for up and down

Status: landed (2026-10-19, 07f9704)

Goal: Space moves the view up and Control moves it down beside E and Q (user, 2026-10-19), the keys a hand on WASD reaches without leaving it.

Verify:
- `./build.sh test` passes with `test_scene_page_key_from_code` (`Space` gives Up, `ControlLeft`, `ControlRight`, `ShiftLeft` and `ShiftRight` give Down, `KeyD` gives Right, an unknown code is not known).
- `./build.sh check` passes, `./build.sh web light` builds.

## Specification

- `src/engine/web_scene_page.odin`: `scene_page_key_from_code` gains `"Space"` for `.Up` and `"ControlLeft"`, `"ControlRight"`, `"ShiftLeft"` and `"ShiftRight"` for `.Down`. Shift is there because the browser owns Control with W (closes the tab), S (saves the page), D (bookmarks) and A (selects all), so Control cannot be held while walking forward, and Shift with those letters does nothing. The procedure moves to `src/engine/scene_page_keys.odin` without a build tag, so the native test suite can call it, with the `Scene_Page_Key` enum beside it.
- `src/engine/scene_page_keys_test.odin` (`#+build !js`): the test above.
- `doc/render.md`, the camera paragraph: Space and Shift or Control with E and Q in the sentence that names them.
