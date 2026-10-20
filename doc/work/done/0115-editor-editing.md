# 0115: Editing in the editor

Status: landed (2026-10-20, 405229c)

Goal: the user corrects any step in game: brush paint on assign steps, key editing in a panel, steps inserted, deleted, moved, enabled and disabled, saved, rerun from the edited step.

Verify:
- `./build.sh test` with the new tests (the pure editing procedures), `./build.sh smoke`; shots of a painted stroke and of the key panel.

## Specification

- Pure procedures in `src/app/editor_edit.odin` with tests: `editor_add_stroke`, `editor_erase_stroke_near`, `editor_insert_step(op)`, `editor_delete_step`, `editor_move_step`, `editor_toggle_step`, `editor_adjust_key(step, key, direction)` (each key a step size and limits), with `editor_edit_test.odin`.
- A CPU ray pick of a step's input mesh (`pipeline.ray_pick(mesh, origin, direction) -> (position, triangle, hit)`) with a test.
- Brush: the cursor (mouse, or the right stick in brush mode), paint and erase buttons, radius by wheel or shoulders, part cycle; the brush ring drawn at the hit; each stroke's triangle count shown. Every edit reruns from that step; Save (S or Start) writes the file.
