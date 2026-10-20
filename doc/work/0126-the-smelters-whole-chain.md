# 0126: The smelter's whole chain

Status: designed (2026-10-20)

Goal: the smelter's pipeline holds every step from the generated model to the exported game model, so the editor's line runs from the 1.46 M triangle base to what the game draws.

Verify:
- The editor's line shows every step; the export lands; the LOD demo draws the exported smelter; shots of the line and of the demo.

## Specification

- `data/machines/smelter/pipeline.sjson`: after the screw repairs, `delete_loose`, `normals`, `levels` (192000 down to 1500), `occlusion`, `curvature`, `emissive`, `pivot` for the lid, `socket` for heat, `export`. Written by the main agent once 0121 to 0125 land.
