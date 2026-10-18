# 0018: The cave page

Status: landed (2026-10-18, d2a7cc4)

Goal: the first picture of D1's target, a cave lit by its own flora: rock walls and stalagmites in two rock materials, patches of glowing moss and clusters of glowing fungus, each with a point light of its colour, no sun, a low ambient and a raised exposure. A second page, `cave`, beside `light`, built from a scene file and the engine's `Scene_Page`. Builds on 0017.

Verify:
- `./build.sh check`, `./build.sh web cave`; the page shows a dark cave where the moss and fungus light the rock around them, orbitable (the user).

## Specification (main agent, 2026-10-18)

- `data/materials/library.sjson`, four materials: `cave_rock` albedo [0.30, 0.27, 0.24] roughness 0.95 metallic 0; `wet_rock` albedo [0.16, 0.15, 0.14] roughness 0.30 metallic 0; `glow_moss` albedo [0.10, 0.30, 0.15] roughness 0.80 metallic 0 emissive [0.4, 1.6, 0.8]; `glow_fungus` albedo [0.30, 0.15, 0.05] roughness 0.70 metallic 0 emissive [1.6, 0.7, 0.2]. `src/engine/material_test.odin` drops its count assertion on the shipped library (the spec wrongly said it had none): the shipped file test checks the parse and two known materials, not the count.
- `data/demos/cave/scene.sjson`: camera target [0, 1, 0] yaw 0.4 pitch 0.35 distance 8; sun direction [0, -1, 0] colour [0, 0, 0] intensity 0; exposure 2; ambient 0.02; items: the floor box [14, 0.2, 14] at [0, -0.1, 0] cave_rock, the back wall box [14, 5, 0.4] at [0, 2.5, -7] cave_rock, the left wall box [0.4, 5, 14] at [-7, 2.5, 0] cave_rock, the right wall box [0.4, 5, 14] at [7, 2.5, 0] cave_rock (added after the review: on a landscape canvas the open right side showed the clear colour), a ceiling box [14, 0.4, 14] at [0, 5.2, 0] cave_rock; five stalagmites, cylinders radius 0.35 height 1.8 segments 12 in wet_rock at [-4, 0.9, -3], [-2.5, 0.9, 2], [3, 0.9, -4.5], [4.5, 0.9, 1], [0.5, 0.9, -1.5]; three moss patches, boxes [1.2, 0.06, 1.2] in glow_moss at [-5, 0.03, -5], [2, 0.03, -5.5], [-5.5, 0.03, 3]; four fungus clusters, cylinders radius 0.18 height 0.5 segments 10 in glow_fungus at [-1, 0.25, -5.5], [4, 0.25, -2], [-4, 0.25, 0.5], [1.5, 0.25, 3]; lights: one above each moss patch (y 0.4, colour [0.25, 1.0, 0.5], intensity 1.5, range 5) and one above each fungus cluster (y 0.7, colour [1.0, 0.45, 0.12], intensity 1.5, range 4). That is seven lights of the eight the shader takes.
- `src/demos/cave/main.odin`: the light demo's file with the scene path changed and the header comment naming the cave.
- `PLAN.md`: the D1 row names the cave page as the first scene of the demo.

Verify: `./build.sh check` (silent), `./build.sh test` (twenty two tests), `./build.sh web cave`.
