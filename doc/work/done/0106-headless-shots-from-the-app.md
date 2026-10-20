# 0106: Headless shots from the app

Status: landed (2026-10-20, ef79f07)

Goal: the main agent renders close-ups of any demo from a chosen view and configuration without a display, and looks at them before the user does (user, 2026-10-20: "start taking screenshots yourself of closeups to see what each process step produces"). The app draws with the pages' renderer, so its shots stand for both; 0009 (the browser) stays open.

Verify:
- `./build.sh check`, `./build.sh test` with the new test, `./build.sh smoke`; `tools/shoot.sh parts tmp/shots/parts.png --view 0.5,0.3,2.5,0,0.5,0` writes a PNG that is not a single colour, and the main agent looks at it.

## Specification

- `src/app/main.odin` `Options`: `shot: string` (`--shot <path>`), `view: Maybe(engine.Orbit)` (`--view yaw,pitch,distance,x,y,z`, six numbers), `configuration: int` (`--configuration <n>`). A pure `parse_view(text) -> (engine.Orbit, bool)`; test `test_parse_options_reads_the_shot_view_and_configuration` in a new `src/app/options_test.odin` (`#+build !js`). The usage line names them.
- After `enter_demo`: with `view`, `view.orbit` is that orbit and `view.fly` is `engine.fly_from_orbit` of it (so it works in both camera modes); `configuration` is set modulo the scene's count. With `shot`, the app draws `frames` frames (at least 3), and on the last one captures the screen with `rl.LoadImageFromScreen` after the scene and before `rl.EndDrawing`, writes it with `rl.ExportImage` to the path, unloads it, prints `shot: <path>` and exits 0 (1 with a line on stderr when the export fails). In a shot the labels, the stamp, the corner text and the LOD panel are not drawn, so the image is the scene alone.
- New `tools/shoot.sh <demo> <out.png> [app arguments ...]`: builds the debug app unless `build/bedrock-array` is newer than every file under `src/` and `data/` (or always, if simpler), then runs it under `xvfb-run -a -s "-screen 0 1280x720x24" env XDG_SESSION_TYPE=x11` with `--windowed --demo <demo> --shot <out.png>` and the rest, creating the output directory.
- `doc/build.md`: the shot options and the script, in the native build section.
