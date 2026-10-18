# The material workflow

The first asset workflow (definition.md, lesson 3): how a material of the library gets its texture set, and how a set is judged before it lands. Decided 2026-10-18 with item 0028, the research behind it in `doc/log/2026-10-18.md`.

## The pipeline

A material's look is procedural nodes in Blender, baked headless to a tileable texture set by `tools/materials/bake.py`, with the parameters read from a file under `data/materials/bake/`. The chipping is not baked: the renderer cuts a baked wear field against the distance to the primitive's edges (later against a curvature mask baked per model), so chips land on edges whatever the mesh. The library preset tints the set, so one set serves every family colour.

Blender 5.2 runs as the flatpak `org.blender.Blender`, headless on the CPU (Cycles sees no GPU on this machine, which bakes a 1024 map well under a second). Its bundled Python has numpy, which the scripts use for the normal map and the checks.

Files, per material `<name>`:

- `data/materials/bake/<name>.sjson`: the bake parameters and the seed.
- `data/materials/textures/<name>_albedo.png`: sRGB, near white with the mottle, tinted in the shader by the preset's `albedo`.
- `data/materials/textures/<name>_normal.png`: linear, tangent space, OpenGL (+Y up), from the baked height by wrap around differences, so it tiles like the rest.
- `data/materials/textures/<name>_surface.png`: linear, R the paint's roughness, G the bare metal's roughness, B the wear field.
- In `data/materials/library.sjson` the preset names its set with `textures = "<name>"` and its wear rule with `wear = { edge_width, chip_threshold, amount, metal }`, `metal` the bare metal's colour under the chipped paint.

Maps are 512 square: the sets are low detail by design, a page embeds them and the phone decodes them, and at the 2 m near scale that is 256 texels per metre. Larger maps are a phase B question. Every map is tileable: the nodes feed 4D noise with the texture coordinate wrapped onto a torus, so the texture's period is the map.

## The steps

1. Write or edit `data/materials/bake/<name>.sjson`.
2. Bake: `flatpak run org.blender.Blender -b --python "$PWD/tools/materials/bake.py" -- <name>` from the repository root (the flatpak starts in its own directory, so the script path is absolute; the script finds the data from its own location), which writes the three maps and prints the seam check: each map's edge difference against the image's mean neighbour step.
3. Review: `flatpak run org.blender.Blender -b --python "$PWD/tools/materials/review.py" -- <name>`, which writes `work/materials/<name>_review.png` and prints the checks.
4. The agent reads the review image and the checks, then the user judges the review image and, once the set is on a page, the page. A set lands only on the user's yes.

The wear rule in the shader: `edge` is the distance from the fragment to the nearest edge of its box, `wear = step(chip_threshold, wear_field + amount * (1 - smoothstep(0, edge_width, edge)))`, and `wear` picks bare metal over paint, roughness G over R, and sets metallic to one. The review sheet builds the same rule in nodes, so the two copies must change together; the three parameters come from the one library file.

## The review sheet

One image: the bevelled box at machine size with the set at both scales and the wear rule, under a sun and a flat sky, near and far; every map tiled 2 by 2, which shows a seam; the albedo tiled 8 by 8 at both scales, which shows repetition. The checks printed with it: the seam difference against the neighbour difference, no autocorrelation peak away from zero, the tinted albedo (the preset's colour times the map) within the plausible sRGB range (about 30 to 240), the map itself being near white, the roughness within its range, the wear coverage within bounds. The checks are mechanical; the look is the user's.

## Rejected

- Parametric generation in Odin, as Mine oh Belowed's field tiles: every noise primitive would be rebuilt, and nothing renders a review image headless. It keeps one merit, live rerolls in the in game editor, which is an open call (SUGGESTIONS.md).
- Material Maker: a fitting tool, but its graphs are awkward for an agent to write and its command line export needs a display.
- AI generators, local or hosted: this GPU runs none of them (ROCm has no gfx1010), the hosted ones return an albedo with derived maps, drift in style between runs, and know nothing of a box's edges. A target image for the review sheet is the one use left, an open call.
- Scan libraries (ambientCG, Poly Haven, CC0): photographic grime is what the look excludes. Their renders serve as a reference beside the review sheet if wanted.
- Noise in the fragment shader: several octaves with derivatives per projection and scale is more than the phone should pay.
