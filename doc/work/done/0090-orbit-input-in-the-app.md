# 0090: Orbit input in the app

Status: landed (2026-10-19, 643c170)

Goal: the app drives an orbiting scene (0088) like the page (0089): the mouse turns while its left button is down, the wheel zooms, the pad's shoulders step the configuration both ways. The arrows stay walk keys until 0093.

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh debug`, `./build.sh release`, `./build.sh smoke`.

## Specification

- `src/app/main.odin`: `APP_WHEEL_ZOOM_PER_NOTCH :: f32(0.1)`. `frame_input` takes the view's camera mode: in orbit mode the mouse delta turns only while `rl.IsMouseButtonDown(.LEFT)`, `zoom = rl.GetMouseWheelMove() * APP_WHEEL_ZOOM_PER_NOTCH`. In `main` the shoulder edges, taken like the North edge, set `previous_configuration` (left) and `cycle_configuration` (right) in both modes. The corner text reads `LB RB: <name>`.
- `doc/build.md`: the controls paragraph names the orbit mouse, the wheel and the shoulders.
