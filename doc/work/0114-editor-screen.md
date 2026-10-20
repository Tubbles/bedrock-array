# 0114: The editor screen

Status: designed (2026-10-20)

Goal: the app's pipeline editor: an asset's steps listed, up to four step views side by side under one orbit camera, parts in false colour or their brief materials (doc/workflows/pipeline_editor.md, The editor).

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh smoke` (a headless run of `--edit smelter --frames 3`); shots of the editor read by the main agent.

## Specification

- `src/app/editor.odin`: `Editor {pipeline_path, run: pipeline.Run, selected: int, shown: [dynamic]int (up to four step indices), orbit, false_colour: bool, uploads per shown step}`; `editor_open(id)` (parses, runs native steps), `editor_step(editor, input)`, `editor_draw(editor)`: the step list on the left (op, key values, triangles, status), the grid of views (each a viewport of 0113 with each part's triangles uploaded as one mesh, tinted from a fixed palette or in the brief's material), the selected view framed. Uploads are rebuilt when a step's output changes.
- `src/app/main.odin`: `--edit <id>` and a menu entry `editor` (the smelter for now); Escape or East leaves to the menu. Shots work in the editor (`--shot`).
- `doc/build.md`: the editor's controls.
