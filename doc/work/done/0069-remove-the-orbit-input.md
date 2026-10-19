# 0069: Remove the orbit input

Status: landed (2026-10-19, c2305fd)

Goal: with the pages on the fly camera (item 0068) the orbit's drag, zoom, pan and walk have no caller. They go, with their tests, in a commit of their own.

Verify:
- `./build.sh test` passes with the five tests gone (45 tests), `./build.sh check` passes, `./build.sh web light` builds.
- `grep -n "orbit_drag\|orbit_zoom\|orbit_pan\|orbit_metres_per_pixel\|orbit_walk\|orbit_right_and_up" src doc` finds nothing.

## Specification

- `src/engine/render_camera.odin`: remove `orbit_drag`, `orbit_zoom`, `orbit_pan`, `orbit_metres_per_pixel`, `orbit_walk` and the file private `orbit_right_and_up`, with their comments; `ORBIT_PITCH_LIMIT`, `orbit_camera`, `orbit_fit_width`, `stick_dead_zone` and the fly procedures stay. Remove `core:math/linalg` from the imports only if nothing in the file uses it afterwards.
- `src/engine/render_test.odin`: remove `test_orbit_drag_turns_and_clamps`, `test_orbit_zoom_scales_and_clamps`, `test_orbit_pan_moves_the_target_in_the_view_plane`, `test_orbit_metres_per_pixel` and `test_orbit_walk_moves_along_the_ground`.
- `doc/render.md`: no mention of the removed procedures remains (item 0068 rewrote the sentences; check with grep).
