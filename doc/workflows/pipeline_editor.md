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

The runner (`src/pipeline/`, native, tested) runs the steps in order and keeps every step's output in memory. An edit to step n reruns from n; the steps before stay cached. `decimate` and `close` write each part as PLY under `work/models/<id>/pipeline/`, run the external tool on a worker thread and read the result back; the editor shows the step as computing meanwhile. The last step's output writes one blob per part to `data/demos/parts/meshes/` (the parts demo) and, for `decimate`, one per level.

## The editor

`--edit <id>` or the menu entry `editor` opens it. Left, the step list: the selected step highlighted, each line its op, its key values and its triangle count. Right, a grid of up to four step views side by side, one orbit camera shared by all, each part in a striking colour (the scene tint) or in its brief material (a toggle). The selected step's view is framed.

- The pad's d-pad or the arrows move through the steps; a shoulder or Page Up and Down add the step to or drop it from the grid.
- A step's keys are edited in a panel like the LOD dials: up and down choose the key, left and right change it, South or Enter resets it.
- Brush mode on an `assign` step: the cursor (the mouse, or the right stick moving a cursor) ray picks the step's input mesh; the left button or the right trigger paints a stroke at the hit, the wheel or the shoulders set the radius, a key cycles the part. Paint adds strokes to the step's select; a second button erases the stroke under the cursor.
- Insert a step after the selected one (a menu of the ops), delete it, move it up or down, enable or disable it.
- Save writes `pipeline.sjson`; quit asks when unsaved.
