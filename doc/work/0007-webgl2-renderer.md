# 0007: The WebGL2 renderer

Status: todo (2026-10-18)

Goal: `src/engine/render_webgl.odin` with the `#+build js` tag, so it is part of the `engine` package for the browser target only: uploads a mesh once, compiles the GLSL ES 3.00 pair (positions and normals in, one directional light and an ambient term with the material's albedo), and draws a `Draw_List`. Physically based shading, HDR and the clustered lights follow in D1's later items. CLAUDE.md: WebGL2 calls only.

Verify:
- `./build.sh check` passes for the browser target through a demo that imports the package.
- The user sees the light demo's primitives lit from one direction (item 0008).
