# 0004: The WebGL2 draw list renderer skeleton

Status: todo (2026-10-18)

Goal: `src/engine/render` with a `Draw_List` of primitives (box, cylinder, drum) in library materials and a camera, drawn through WebGL2 under one directional light, and `src/demos/light` handing over a draw list of a few primitives with an orbit camera driven by touch drag and mouse drag. The demo never reaches into the renderer (CLAUDE.md, Code rules). The first step of D1.

Verify:
- `./build.sh test` passes with a test that builds a draw list and asserts its contents natively.
- The page shows the primitives lit from one direction and the camera orbits by touch and by mouse (the user).
