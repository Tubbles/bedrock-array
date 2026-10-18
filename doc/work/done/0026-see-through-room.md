# 0026: See through room walls

Status: landed (2026-10-18, aac3db5)

Goal: the cave's floor, walls and ceiling become one inside out box, a room, whose faces point into the cave: from inside they draw as before, from outside they are back faces and culled, so a camera that orbits or walks out of the cave looks straight in instead of at a wall (user, 2026-10-18: "when camera gets behind the wall I see only the wall. Can you make the walls floor and roof see through"). Builds on 0018.

Verify:
- `./build.sh check`, `./build.sh test` (twenty eight tests), `./build.sh web cave`; zooming or walking out of the cave shows its inside through the near wall (the user).

## Specification (main agent, 2026-10-18)

- `src/engine/render_mesh.odin`: `room_mesh(size, allocator) -> Mesh_Data`, a `box_mesh` whose normals are negated and whose triangles are wound the other way (swap two indices of every triangle), with a one line comment. `src/engine/render_test.odin`: `test_room_mesh_faces_inward` (every normal points against its vertex position, `dot(normal, position) < 0`, and for every triangle the cross product of its edges agrees with the normal, as `test_box_mesh_has_six_faces` checks for the box).
- `src/engine/scene.odin`: `Scene_Shape` gains `Room`, `shape = "room"` with the box keys (`size`), `scene_item_mesh` gives `room_mesh`; `src/engine/scene_test.odin`: `test_scene_item_mesh_by_shape` also covers a room (24 vertices).
- `data/demos/cave/scene.sjson`: the five rock boxes (floor, back, left, right walls, ceiling) replaced by one room `size = [14, 5, 14]` at `[0, 2.5, 0]` in cave_rock (floor at y 0, ceiling at 5, walls at x and z plus or minus 7), the comment line updated. `src/demos/cave/description.txt`: a sentence that the walls are see through from outside.
- `doc/render.md`: Primitive meshes names `room_mesh`; Scene files names the shape.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty eight tests), `./build.sh web cave`.
