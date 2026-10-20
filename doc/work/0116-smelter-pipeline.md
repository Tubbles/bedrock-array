# 0116: The smelter's pipeline

Status: designed (2026-10-20)

Goal: today's manual finish of the smelter written as its `pipeline.sjson`: import, transform `+x` to 1 m, weld, the assigns of 0102's mapping and overrides (by pieces), the screw cuts of 0108 as stroke assigns, the three copies, then the editor shows it and the user corrects from there.

Verify:
- The editor opens it, every native step runs, and the last step's parts match 0108's blobs in triangle counts within the weld's merges; shots of the steps.

## Specification

Written once 0115 lands, from `data/machines/smelter/generated.sjson` and the 0108 spots.
