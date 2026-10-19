# 0084: The configuration on the pad in the app

Status: landed (2026-10-19, c3ba499)

Goal: in the native app the pad's North button (Y) and the C key cycle the scene's configuration, and a corner shows the current one. Follows 0082.

Verify:
- `./build.sh check`, `test`, `debug`, `release` and `smoke` pass.
- The reviewer traces a frame: a North press cycles once (an edge, not a repeat while held), the corner text matches `scene_view_configuration_name`, and a scene without configurations shows no text.

## Specification

- `src/app/main.odin`: `frame_input` gains `cycle_configuration = rl.IsKeyPressed(.C)`; in the demo screen the pad's North edge (from the same `pressed` set the Start edge uses) also sets it; `draw_frame` draws `Y: <name>` at 20 points in the bottom right corner (right aligned by `rl.MeasureText`, the stamp's margin) when `engine.scene_view_configuration_count(view) > 1`.
- `doc/build.md`: the controls paragraph adds Y or C for the configuration, pad first.
