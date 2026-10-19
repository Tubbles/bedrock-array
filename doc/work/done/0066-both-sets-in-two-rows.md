# 0066: Both sets in two rows

Status: landed (2026-10-19, e41c2d8)

Goal: the first set's models come back on the page beside the second so the difference the triangle count makes can be judged along each lineage (user, 2026-10-19). Nine plaques in one row would overlap on a laptop, so the page becomes two rows: the back row Tripo's parts mode from the full model down, the front row the smart low poly ones and Blender's collapses, each row sorted by triangle count falling.

Verify:
- `./build.sh test` passes (the shipped scenes test parses the nine item scene), `./build.sh check` passes, `./build.sh web models` builds.
- The installed page shows two rows with a plaque each, the back row seen over the front one.

## Specification

- `data/demos/models/meshes/`: `faces12000.mesh`, `faces12000_smart.mesh` and `decimate.mesh` are restored by the main agent before the item runs, nine blobs in all.
- `data/demos/models/scene.sjson`: the camera `{ target = [0, 0.5, 0], yaw = 0, pitch = 0.55, distance = 9, fit_width = 13 }` (the steeper pitch lifts the back row clear of the front one and its plaques), the slab `size = [13, 0.1, 8.5]` at `[0, -0.05, 0]`, the back row on z minus 2.5 at x minus 4.5, minus 1.5, 1.5, 4.5 (3 m apart, since the back row is further and 2.5 m there put its plaques 144 px apart on a laptop, under the plaque's 160): `full.mesh`, `faces700000.mesh`, `faces24000.mesh`, `faces12000.mesh`; the front row on z 2.5 at x minus 5, minus 2.5, 0, 2.5, 5: `faces20000_smart.mesh`, `smart.mesh`, `faces12000_smart.mesh`, `decimate24000.mesh`, `decimate.mesh`; every item `scale = 1` in `painted_steel` on y 0; nine labels at y 1.3 above their models with the texts `full, 29 parts, 1.46 M triangles, 40 credits`, `face limit 700000, 20 parts, 654548 triangles, 40 credits`, `face limit 24000, 37 parts, 20824 triangles, 40 credits`, `face limit 12000, 16 parts, 10700 triangles, 40 credits`, `face limit 20000 and smart low poly, 1 part, 29476 triangles, 30 credits`, `smart low poly, 1 part, 10796 triangles, 30 credits`, `face limit 12000 and smart low poly, 1 part, 10409 triangles, 30 credits`, `Blender decimate of full, 29 parts, 23984 triangles, no credits`, `Blender decimate of full, 29 parts, 10680 triangles, no credits`. The first line comment names the two rows.
- `src/demos/models/description.txt`: `The smelter's generated model and every reduction of it in two rows, Tripo's parts mode behind, the smart low poly ones and Blender's collapses in front, a plaque over each, where a generated model is judged. Drag to orbit, pinch or wheel to zoom.`
- `doc/workflows/models.md`, the "What was not verified" sentence on the sets: replace `so the second set at 700000 and 24000 is on the models page` with `and the second set at 700000 and 24000 stands with it on the models page, in two rows by mode`.
