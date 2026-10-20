# 0116: The smelter's pipeline

Status: landed (2026-10-20, 211970f)

Goal: today's manual finish of the smelter written as its `pipeline.sjson`: import, transform `+x` to 1 m, weld, the assigns of 0102's mapping and overrides (by pieces), the screw cuts of 0108 as stroke assigns, the three copies, then the editor shows it and the user corrects from there.

Verify:
- The editor opens it, every native step runs, and the last step's parts match 0108's blobs in triangle counts within the weld's merges; shots of the steps.

## Specification

- `data/machines/smelter/pipeline.sjson`: after 0114's starter, two assigns of the fused screws to `fittings` by strokes (skirt and body, each `within_part`, the 0108 spots and cut radii) and three copies for the empty holes (a sphere on the source screw within `fittings`, from the source's panel point to the target's, the panel level the median height of the 13 to 16 mm ring).
