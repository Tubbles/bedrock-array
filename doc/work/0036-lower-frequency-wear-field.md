# 0036: Lower frequencies in the wear field

Status: implementing (2026-10-18)

Goal: the user's judgement of the first material (2026-10-18): "the peel is too regular, it needs some lower frequency components as well, in terms of occurrence and flake size". The wear field is one voronoi scale over one noise, so every flake has one size and the flakes spread evenly. The field gains a second, larger voronoi for big flakes and a slow occurrence noise that gathers chips into patches and leaves other regions clean. Refers to items 0030 and 0035.

Verify:
- The bake and the review sheet run with every check ok; on the sheet the flakes come in two sizes and in patches, with clean stretches between; then the surface page, the user's judgement.

## Specification (main agent, 2026-10-18)

- `data/materials/bake/painted_steel.sjson`, the `wear_field` object becomes: `flake_scale = 4` (the small flakes' voronoi, the old `voronoi_scale`), `large_flake_scale = 1.6` (a second voronoi, bigger and fewer cells), `large_flake_weight = 0.8` (how high its blobs reach against the small ones), `occurrence_scale = 1.1` (a slow noise over the tile), `occurrence_amount = 0.5` (how far it lowers the field in the clean regions), `noise_scale = 7` and `blend = 0.5` as before. One member per line.
- `tools/materials/bake.py`, `wear_field_channel`: `small = 1 - voronoi(flake_scale)`, `large = large_flake_weight * (1 - voronoi(large_flake_scale))`, `blobs = max(small, large)` (a `MAXIMUM` math node, so both flake families show when the field is thresholded), `occurrence = noise(occurrence_scale, detail 1)`, `gathered = blobs * (1 - occurrence_amount + occurrence_amount * occurrence)` (the blobs reach the threshold only where the slow noise is high), then `mix(gathered, noise(noise_scale, detail 2), blend)` as before. The stretch to 0 to 1 after the bake stays. Short procedures: the blob families, the occurrence factor, the mix.
- Then rebake (`flatpak run org.blender.Blender -b --python "$PWD/tools/materials/bake.py" -- painted_steel`) and run the sheet (`flatpak run org.blender.Blender -b --python "$PWD/tools/materials/review.py" -- painted_steel`); if the `WEAR coverage` check does not read ok, the threshold in `data/materials/library.sjson` is the main agent's knob, not the implementer's: report the coverage.

Verify: the two commands; `WEAR coverage` between 0.005 and 0.2; the sheet read with the Read tool shows flakes in two sizes gathered in patches.
