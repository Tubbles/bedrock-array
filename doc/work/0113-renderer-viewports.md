# 0113: Renderer viewports

Status: implementing (2026-10-20)

Goal: the renderer draws a draw list into a rectangle of the window, so the editor shows several steps side by side.

Verify:
- `./build.sh test`, `./build.sh check`, `./build.sh web light`, `./build.sh smoke`; a shot of the editor (0114) shows four views without bleeding.

## Specification

- `src/engine/render_gl.odin`: `gl_renderer_draw_viewport(renderer, list, library, x, y, width, height, window_height)` renders the scene, the bloom and the tone map at the rectangle's size (the targets resized as now to the largest rectangle used) and composites into the rectangle of the default framebuffer with the scissor set; `gl_renderer_draw` becomes the full window case. The camera's aspect is the rectangle's.
- `doc/render.md`: the viewport.
