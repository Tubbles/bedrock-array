# 0036: Lower frequencies in the wear field

Status: verified (2026-10-18)

Goal: the user's judgement of the first material (2026-10-18): "the peel is too regular, it needs some lower frequency components as well, in terms of occurrence and flake size". The wear field is one voronoi scale over one noise, so every flake has one size and the flakes spread evenly. The field gains a second, larger voronoi for big flakes and a slow occurrence noise that gathers chips into patches and leaves other regions clean. Refers to items 0030 and 0035.

Verify:
- The bake and the review sheet run with every check ok; on the sheet the flakes come in two sizes and in patches, with clean stretches between; then the surface page, the user's judgement.

## Specification (main agent, 2026-10-18, second form)

The first form (a weighted max of two voronoi blob fields times a raw slow noise) changed nothing visible: a thresholded blob field shows only the blob cores, so every flake is a core of one size and the large family never crosses the threshold. The second form gives each blob an explicit radius, random per cell, and a contrast stretched patch mask.

- `data/materials/bake/painted_steel.sjson`, the `wear_field` object: `flake_scale = 4`, `flake_radius = 0.6`, `large_flake_scale = 1.2`, `large_flake_radius = 0.7`, `occurrence_scale = 1.1`, `occurrence_low = 0.4`, `occurrence_high = 0.7`, `occurrence_amount = 0.7`, `noise_scale = 7`, `blend = 0.5`, one member per line.
- `tools/materials/bake.py`, `wear_field_channel`: a flake family at a scale with a radius is a 4D voronoi's F1 `distance` and its per cell random `colour` (red of a Separate Color node), `radius_cell = radius * (0.3 + 0.7 * random)`, `blob = clamp(1 - distance / radius_cell, 0, 1)`; `blobs = max(small, large)`; the patch mask `smoothstep(occurrence_low, occurrence_high, noise(occurrence_scale, detail 1))` (a Map Range node, smoothstep, clamped), `patch = 1 - occurrence_amount + occurrence_amount * mask`; `field = mix(patch * blobs, noise(noise_scale, detail 2), blend)`, stretched to 0 to 1 after the bake as before. Short procedures: the blob family, the patch factor, the channel.
- Rebake and run the sheet; the `chip_threshold` of the library is the main agent's knob.

Verify: the two commands; `WEAR coverage` between 0.005 and 0.2; the sheet read with the Read tool shows flakes of varied size gathered in patches with clean stretches.

Tuned on the sheet by the main agent, 2026-10-18: at the specified values the faces stayed clean (a 2D slice of a 4D voronoi lies far from most feature points, so the blobs were rare), so `flake_radius` 1.0, `large_flake_radius` 1.2 and `blend` 0.35 in the bake file, and `chip_threshold` 0.5 in the library (coverage 0.033).
