# 0093: The arrows step the orbit's focus

Status: landed (2026-10-19, 9cba871)

Goal: on the page and in the app, in orbit mode, the arrows left and right and the pad's d-pad left and right step the orbit's focus (0092); in fly mode they keep walking.

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh web light`, `./build.sh debug`, `./build.sh smoke`.

## Specification

- `src/engine/web_scene_page.odin`: `Scene_Page.focus_pending: int`, handed to `Scene_Input.focus_step` and cleared in `scene_page_step`. In orbit mode a key down of `ArrowLeft` adds minus one and `ArrowRight` one, neither entering `keys_held`; the pad's d-pad left (button 14) and right (15) edges do the same, held state in `Scene_Page` like `north_held`.
- `src/app/main.odin`: in orbit mode `keyboard_walk` leaves out the left and right arrows (a parameter), `rl.IsKeyPressed(.LEFT)` and `.RIGHT` give the focus step, and in `main` the d-pad left and right edges, taken like the North edge, add to it.
- Docs: the page input sentence in `doc/render.md` and the controls paragraph in `doc/build.md`.
