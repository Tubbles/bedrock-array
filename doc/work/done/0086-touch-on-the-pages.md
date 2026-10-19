# 0086: Touch on the pages

Status: landed (2026-10-19, 9b4ada5)

Goal: a phone can move through a scene page, and a finger turns the view the way a finger expects (user, 2026-10-19: "I cannot interact with the web page on a phone, no pinch to zoom, nothing? Just pitch and yaw by dragging a finger", "the pitch and yaw directions are inverted to what I would assume with a finger"). Follows 0073, which dropped the pinch with the orbit.

Verify:
- `./build.sh test` (the new tests pass), `./build.sh check`, `./build.sh web light` and `./build.sh web models` build, `./build.sh smoke` passes.

## Specification

- `src/engine/scene_view.odin`: `Scene_Input` gains `move: [3]f32`, metres in the fly's frame (x right, y up, z forward), applied unscaled after the turn and before the walk: `if input.move != {} do view.fly = fly_walk(view.fly, input.move, 1)`. Comment on the field.
- New `src/engine/scene_touch.odin` (no build tag), the pure gesture kernels:
  - `touch_turn :: proc(movement: [2]f32, radians_per_pixel: f32) -> [2]f32` returns `-movement * radians_per_pixel`: a finger drags the scene, so a drag right looks left and a drag down looks up, the mouse's opposite.
  - `touch_pair_move :: proc(previous, current: [2][2]f32, metres_per_pixel: f32) -> [3]f32`: spread = change of the distance between the two fingers, midpoint = change of their midpoint (client pixels, y down); returns `{-midpoint.x, midpoint.y, spread} * metres_per_pixel`. Spreading walks forward, pinching back, dragging both fingers moves the fly with the scene (right goes left, down goes up).
- New `src/engine/scene_touch_test.odin` (`#+build !js`): `test_touch_turn_drags_the_scene` (a drag right gives a negative x turn, which `fly_turn` makes a yaw increase; a drag down a negative y), `test_touch_pair_move_spread_walks_forward` (fingers 100 px apart moving to 200 px with a fixed midpoint give z = 100 * metres_per_pixel, x = y = 0), `test_touch_pair_move_drag_moves_with_the_scene` (both fingers 50 px right and 50 px down give x < 0, y > 0, z = 0), and in `scene_view_test.odin` `test_scene_view_step_moves_unscaled` (a move of {0, 0, 2} at yaw 0 lands at z = -2 whatever the delta time).
- `src/engine/web_scene_page.odin`: `SCENE_PAGE_PINCH_METRES_PER_PIXEL :: f32(0.02)`; `Scene_Page` gains `move_pending: [3]f32`, handed to the input and cleared in `scene_page_step` like `turn_pending`. `on_scene_page_pointer_move` drops the `is_primary` return (the remaining finger of a pair must turn); after the find, it keeps a copy of the clients, stores the new client, and with two pointers down adds `touch_pair_move` of the old and new client pairs to `move_pending` and turns nothing; with one it turns by the client delta, through `touch_turn` for a pointer whose `pointer_type` is not `.Mouse` and as now for the mouse. Update the comments of the struct and the handler.
- Docs: in `doc/render.md` the page input sentence (line 11, "The page's input is the fly camera's") states the finger's turn direction and the two finger pinch and drag with `SCENE_PAGE_PINCH_METRES_PER_PIXEL` and `Scene_Input.move`. The sentence "A finger looks on the phone, a gamepad walks and looks." in `src/demos/{light,surface,cave,models}/description.txt` becomes "On the phone a finger looks, two fingers spread and pinch to walk and drag to move sideways and up, a gamepad walks and looks."
