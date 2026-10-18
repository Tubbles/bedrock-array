# 0025: The surface page

Status: todo (2026-10-18)

Goal: D1's second scene, a surface under the sun: a ground of soil and grass, a few boulders and a painted steel machine block with copper pipes, lit by a low afternoon sun with a blue sky and a brown ground ambient, exposure 1. The page where the sun, the sky ambient and the materials are judged in daylight. Builds on 0024.

Verify:
- `./build.sh check`, `./build.sh web surface`; the page shows a sunlit surface with soft blue shadows (the user).

## Specification (main agent, 2026-10-18)

- `data/materials/library.sjson`, three materials: `soil` albedo [0.28, 0.20, 0.13] roughness 0.95 metallic 0; `grass` albedo [0.20, 0.36, 0.12] roughness 0.90 metallic 0; `boulder` albedo [0.42, 0.40, 0.37] roughness 0.85 metallic 0.
- `data/demos/surface/scene.sjson`: camera target [0, 1, 0] yaw 0.7 pitch 0.3 distance 10; sun direction [-0.5, -0.6, -0.4] colour [1.0, 0.93, 0.82] intensity 1.2; exposure 1; ambient 0.15; sky_colour [0.25, 0.35, 0.55]; ground_colour [0.16, 0.12, 0.08]; items: the ground box [30, 0.3, 30] at [0, -0.15, 0] soil; four grass patches, boxes [6, 0.04, 6] in grass at [-5, 0.02, -4], [6, 0.02, 3], [-3, 0.02, 6], [4, 0.02, -7]; four boulders, cylinders radius 0.9 height 1.2 segments 10 in boulder at [-6, 0.6, 2], [7, 0.6, -5], [2, 0.6, 8], [-8, 0.6, -8]; a machine: a box [3, 2, 2] at [0, 1, 0] painted_steel, a box [0.8, 0.8, 0.8] at [1.9, 2.4, 0] bare_alloy, three pipes, cylinders radius 0.12 height 2.6 segments 12 in copper at [-1.2, 1.3, 1.1], [-0.6, 1.3, 1.1], [0, 1.3, 1.1]; no lights.
- `src/demos/surface/main.odin`: the cave demo's file with the scene path changed and a header comment naming the surface; `src/demos/surface/description.txt` for the index card.
- `PLAN.md`: the D1 milestone row names the surface page as the second scene.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty seven tests), `./build.sh web surface`.
