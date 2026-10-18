# 0028: The material workflow

Status: designing (2026-10-18)

Goal: D1's decisive step. The workflow for textures and materials, lesson 3 of the definition, chosen and written down as the first asset workflow, and proven by its first finished material: worn painted steel, a physically based set (albedo, normal, roughness, metallic) with a wear mask, tileable and isotropic, on the machine block of the surface page. The user judges the look on the page (DESIGN.md, The target: stylised realism). The renderer work the chosen workflow needs (texture sets in the material library, triplanar sampling at two scales, the wear rule on primitives) follows as items of their own.

Verify:
- `doc/workflows/materials.md` exists: the chosen pipeline, the exact steps and commands that produce a material from its inputs, the review step before a material lands, the rejected alternatives in a few lines.
- The first material set is produced by those steps, committed through Git LFS, and shows on the surface page's machine block.
