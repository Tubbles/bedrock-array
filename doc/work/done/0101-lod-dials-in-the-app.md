# 0101: The LOD dials in the app

Status: landed (2026-10-19, 494a5ed)

Goal: an on screen panel in the app that tunes the level settings live from the pad or the keys, with defaults, reset and the effect read back (the user's liking for in game editors, gamepad first).

Verify:
- `./build.sh test` with the new tests, `./build.sh check`, `./build.sh debug`, `./build.sh release`, `./build.sh smoke`.

## Specification

- New `src/app/lod_panel.odin`: `Lod_Panel {open: bool, row: int}`, `Lod_Panel_Input {toggle, up, down, left, right, reset: bool}`, `lod_panel_step :: proc(panel: ^Lod_Panel, settings: ^engine.Lod_Settings, input: Lod_Panel_Input)` (rows: pixels per triangle times or over the square root of two within 1 to 64, hysteresis by 0.05 within 0 to 0.5, crossfade by 0.1 s within 0 to 2, tint and freeze toggled by left or right; reset sets the row's default from `LOD_SETTINGS_DEFAULT`) and `lod_panel_draw` (top left, one line per row with its value, the selected row marked, then the triangles drawn this frame and the count of items per level). Tests in `lod_panel_test.odin`: `test_lod_panel_moves_and_wraps`, `test_lod_panel_adjusts_within_limits`, `test_lod_panel_reset_restores_the_default`.
- `src/engine/scene_view.odin`: `scene_view_level_counts :: proc(view: ^Scene_View) -> (triangles: int, items_per_level: [8]int)` from the current levels (and the plain items' meshes), for the read back.
- `src/app/main.odin`: in a demo whose scene has level items, Back or Tab toggles the panel; while open the d-pad and the arrows drive it (not the walk, rise, sink or focus), South or Enter resets the row. `doc/build.md` names the controls.
