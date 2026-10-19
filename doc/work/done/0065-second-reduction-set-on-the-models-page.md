# 0065: The second reduction set on the models page

Status: landed (2026-10-19, 14ac15e)

Goal: the first set's reductions to about ten thousand triangles were unacceptable beside the full model, only the smart low poly one somewhat acceptable, and Blender's collapse at over 99 percent a jumbled mess of triangles and holes (user, 2026-10-19). The second set halves the full model's count through Tripo (a face limit of 700000) and doubles the low poly budget to 24000 (20000 with smart low poly, Tripo's cap for that mode), with Blender's decimation at 24000 beside them, on the same page.

Verify:
- `./build.sh test` passes (the shipped scenes test parses the six item scene), `./build.sh check` passes, `./build.sh web models` builds.
- The installed page shows six models in a row with a plaque each.

## Specification

- `data/demos/models/meshes/`: `faces12000.mesh`, `faces12000_smart.mesh` and `decimate.mesh` are removed with `git rm` (the directory is embedded whole, so only what the scene shows stays), `faces700000.mesh`, `faces24000.mesh`, `faces20000_smart.mesh` and `decimate24000.mesh` are added by the main agent before the item runs; `full.mesh` and `smart.mesh` stay.
- `data/demos/models/scene.sjson`: the slab `size = [15.5, 0.1, 4]`, the camera `fit_width = 15.5` and `distance = 9`, six mesh items at x minus 6.25, minus 3.75, minus 1.25, 1.25, 3.75, 6.25 in the order `full.mesh`, `faces700000.mesh`, `faces24000.mesh`, `faces20000_smart.mesh`, `smart.mesh`, `decimate24000.mesh`, each `scale = 1` in `painted_steel` on y 0, and six labels at y 1.3 above them: `full, 29 parts, 1.46 M triangles, 40 credits`, `face limit 700000, 20 parts, 654548 triangles, 40 credits`, `face limit 24000, 37 parts, 20824 triangles, 40 credits`, `face limit 20000 and smart low poly, 1 part, 29476 triangles, 30 credits`, `smart low poly, 1 part, 10796 triangles, 30 credits`, `Blender decimate of full, 29 parts, 23984 triangles, no credits`. The first line comment names the second set.
- `src/demos/models/description.txt`: `The smelter's generated model, Tripo's reductions of it at half and at a 24000 face limit, and Blender's decimation, a plaque over each, where a generated model is judged. Drag to orbit, pinch or wheel to zoom.`
- `doc/workflows/models.md`, the paragraph "What was not verified": one sentence with the first set's verdict, that Tripo's reductions to about ten thousand triangles and Blender's collapse to that count were unacceptable beside the full model, only the smart low poly one somewhat acceptable, the second set at 700000 and 24000 on the models page; and in step 1, after the face limit sentence's flags, that with `--smart-low-poly` the API caps `--face-limit` at 20000 (HTTP 400 above it, nothing charged), and that the sidecar's credits line is the balance before minus after, so two runs at once each record the sum (the main agent corrected this set's sidecars by hand).
