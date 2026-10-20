# 0117: The editor as a line of machines

Status: landed (2026-10-20, 327d902)

Goal: the pipeline editor becomes a world like the LOD demo: every step's output is its own machine standing in a line, the base model first and the finished one last, each machine the input of the next, walked along with the fly camera (user, 2026-10-20: "a long line of machines where the first machine is the 1.4M base model, then next to it the first step output, and so on ... i can then orient around them using the fly camera"). Replaces 0114's grid of four views.

Verify:
- `./build.sh check`, `./build.sh test`, `./build.sh smoke`; shots of the line from the start, from beside a middle machine, and of a brush stroke on a machine, read by the implementer and the main agent.

## Specification

- `src/app/editor.odin` and its siblings: the views and the grid go; one fly camera (`engine.Fly`, the LOD demo's walk and look: WASD, Space and Shift, the mouse with the cursor captured, the sticks) over a concrete floor under the whole line. Machine n stands at x = n * `EDITOR_MACHINE_SPACING` (2 m), z 0, drawn from its step's output, each part one uploaded mesh as now, in false colour or the brief's materials. A step still running shows a plain grey box of the model's bounds with the plaque saying so, a failed step a red box. A disabled step's machine is drawn dimmed (tint 0.35).
- Above each machine a plaque in screen space (the scene label way: projected, raylib text): the step's number, op and key summary, its triangles, and its state. The step under the crosshair (a ray from the screen centre against each machine's bounds) or, when none, the one nearest the camera, is the selected step; its plaque is highlighted and its bounds drawn as lines. The step list moves to a narrow overlay on the left, toggled by L, showing the selection.
- Brush mode: the crosshair is the brush cursor; the ray picks the selected machine's mesh (its output, offset by its position); a stroke is stored in the mesh's own frame (the offset removed). The stroke counts show on the plaque.
- Uploads: a machine is uploaded when it comes within 12 m of the camera and released beyond 20 m, so GPU memory holds a handful of 1.5 M triangle machines, not every step. Each upload is rebuilt when its step's output changes, as now.
- The camera starts beside machine 0, looking down the line. Leaving, saving, the key panel, the op menu and the edits work as in 0115.
- `doc/build.md` and `doc/workflows/pipeline_editor.md` (The editor) describe the line.
