# 0030: The material bake script

Status: todo (2026-10-18)

Goal: step 2 of `doc/workflows/materials.md`: `tools/materials/bake.py` turns a bake parameter file into the three tileable maps, and the first parameter file, worn painted steel, with its baked set committed through Git LFS. Refers to items 0028 and 0029.

Verify:
- `flatpak run org.blender.Blender -b --python tools/materials/bake.py -- painted_steel` writes `data/materials/textures/painted_steel_albedo.png`, `_normal.png` and `_surface.png`, 512 square, and prints the seam check with a seam difference no larger than the neighbour difference for every map.
