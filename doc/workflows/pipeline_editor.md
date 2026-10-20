# The asset pipeline editor

Decided 2026-10-20 (user): every step that turns a generated model into a game model is a primitive operation stored as data, and the user corrects any step in game instead of the main agent guessing it from scripts and shots ("all the manual steps you carry out should be saved in a data format, and I want to be able to go in and make fine adjustments, add, or remove", "steps that are of primitive nature, not specialized unless necessary"). The editor is a screen of the app, native only, driven by pad, keys and mouse like the LOD panel.

## The pipeline file

`data/machines/<id>/pipeline.sjson`: `source` (the generated GLB, a path under the project) and `steps`, an array run in order on one mesh. The mesh is triangles with positions, normals, a piece per triangle (the generator's node it came from, or a copy's new piece) and a part per triangle (a brief part name, or none). Each step is an object with `op` and its keys; a step may carry `note` (free text) and `enabled = false`.

| op | keys | does |
|---|---|---|
| `import` | none | reads `source`; every root node becomes a piece, part none. Always the first step, added by the editor. |
| `transform` | `front` (`+x`, `-x`, `+z`, `-z`, the axis that becomes +z), `height` (metres) | grounds the bounding box's bottom centre at the origin, turns, scales to the height |
| `weld` | `metres` | merges vertices closer than that |
| `assign` | `part`, `select` | gives the selected triangles that part |
| `delete` | `select` | removes the selected triangles |
| `copy` | `select`, `from`, `to`, `turn` (quarter turns about y, 0 to 3) | adds a copy of the selected triangles, turned about `from` and moved to `to`, as a new piece with the same parts |
| `decimate` | `triangles` (the total budget, shared by the parts in proportion) | per part, through Blender's `tools/models/decimate.py` |
| `close` | `part`, `technique` (`poisson`, `fill`), `trim` (metres) | per part, through `tools/models/reconstruct.py` or `close.py` |

A `select` is one of: `{ pieces = ["tripo_part_4", ...] }`, `{ part = "body" }`, `{ box = { min = [x, y, z], max = [x, y, z] } }`, `{ sphere = { centre = [x, y, z], radius = r } }`, `{ strokes = [ { position = [x, y, z], radius = r } ... ] }` (a triangle is selected when its centroid lies within a stroke's radius), and an optional `within_part = "body"` that narrows any of them. Positions are metres in the frame of the step's input, so a stroke stays where it was painted when an earlier step changes the triangles; after a big upstream change a stroke may land wrong, and the editor shows how many triangles each stroke takes.

## The run

The runner (`src/pipeline/`, native, tested) runs the steps in order and keeps every step's output in memory. A step that changes no vertex and no triangle (an `assign`, or any disabled step) shares its input's geometry (positions, normals, triangles and pieces) and holds only its own parts; every other step makes new geometry. An edit to step n reruns from n; the steps before stay cached. `decimate` and `close` write each part as PLY under `work/models/<id>/pipeline/`, run the external tool on a worker thread and read the result back; the editor shows the step as computing meanwhile. The last step's output writes one blob per part to `data/demos/parts/meshes/` (the parts demo) and, for `decimate`, one per level.

## The editor

`--edit <id>` or the menu entry `editor` opens it. The steps stand as a line of machines on a concrete floor, machine n the output of step n at x = 2n metres, the import first and the finished model last, walked along with the fly camera of the LOD demo. Each part is drawn in a striking colour (the scene tint) or in its brief material (a toggle); a step without output yet shows as a grey box of the model's bounds, a failed one as a red box, a disabled step's machine dimmed. Above each machine near the camera a plaque gives the step's number, op and keys, its triangles and its state (the farther ones only the title, and the state of a step not done). The machine under the crosshair, else the one nearest the camera, is the selected step: its plaque is highlighted and its bounds drawn as lines. A narrow list of the steps on the left shows the selection.

- Machines sharing one geometry share one vertex upload and each holds only its index lists. A geometry and every machine sharing it are uploaded while the camera is within 12 m of one of them and released beyond 20 m.
- A step's keys are edited in a panel like the LOD dials: up and down choose the key, left and right change it, South or Enter resets it. The selection holds while the panel, the insert menu or the brush is open.
- Brush mode on an `assign` step: the crosshair ray picks the selected machine's mesh; the left button or the right trigger paints a stroke at the hit, stored in the machine's own frame, the wheel or the shoulders set the radius, a key cycles the part, a second button erases the stroke under the crosshair. The selected plaque shows the triangles each stroke takes.
- Insert a step after the selected one (a menu of the ops), delete it, move it up or down, enable or disable it.
- Save writes `pipeline.sjson`; quit asks when unsaved.
