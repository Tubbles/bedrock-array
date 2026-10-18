# 0042: The blockout script

Status: landed (2026-10-18, 3f68fd7)

Goal: step 2 of `doc/workflows/art_book.md`: `tools/art/blockout.py` builds a machine's blockout from its brief, primitives in library materials with the 1.8 m figure beside it under the review light, and renders the hero view, the four orthographic views and a silhouette mask of each, the reference images the repaint step takes. Refers to items 0038 and 0041.

Verify:
- `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- smelter` writes `work/art/smelter/blockout/hero.png`, `front.png`, `left.png`, `back.png`, `right.png` and `hero_mask.png` to `right_mask.png`, 1024 square; the hero shows the drum with its glowing window and the figure beside it, read with the Read tool.

## Specification (main agent, 2026-10-18)

Binding facts: the brief's keys (`data/machines/smelter/brief.sjson`: `parts[].blockout` with `shape` `box` (`size`), `cylinder` (`radius`, `height`) or `dome` (`radius`, `height`, the upper half of a sphere scaled to the height), `position` the shape's centre in metres from the footprint's bottom centre, y up, the front facing +z; `figure_metres`; `height_metres`); the library presets (`data/materials/library.sjson`: `albedo`, `roughness`, `metallic`, optional `emissive`); the light of the material review sheet (`tools/materials/review.py`: `add_sky`, `add_ground`, `add_light_camera_world`, a sun, a single scattering sky, AgX); the SJSON reader `tools/materials/sjson.py`.

- `tools/materials/review.py` gains the `if __name__ == "__main__": main()` guard so its scene procedures import without running, and nothing else changes there.
- `tools/art/blockout.py`, run as `flatpak run org.blender.Blender -b --python "$PWD/tools/art/blockout.py" -- <id>`: puts `tools/materials` on `sys.path`, reads the brief and the library, resets the scene, builds one object per part from its `blockout` (`primitive_cube_add` scaled to `size`, `primitive_cylinder_add` with the radius and depth, `primitive_uv_sphere_add` scaled to the radius and the height and cut to its upper half by a boolean or by deleting the lower vertices, each at its `position`, y up: Blender's z is up, so the brief's `[x, y, z]` maps to Blender's `(x, -z, y)`), each with a Principled material from its preset (base colour the albedo, roughness, metallic, emission the emissive colour at strength 1 when present), named by the part. The figure: a capsule of `figure_metres`, a cylinder of radius 0.2 with a sphere head, mid grey roughness 0.8, standing on the ground at 1.4 m to the machine's right (+x) and level with its front. The ground and the sky of the material sheet, the sun the same.
- Cameras: the hero, a perspective camera at three quarters from the front left and a little above (looking down about 15 degrees), framing the machine and the figure with a margin of about a tenth; the four orthographic cameras `front` (+z side looking along -z), `left` (-x side), `back`, `right`, `ortho_scale` 1.2 times the larger of the machine's height and its footprint diagonal, centred at half the height. 1024 square, Cycles on the CPU, 32 samples, denoised, AgX, as the sheet.
- Masks: for every view a second render with the figure, the ground and the sky hidden and every part under one white emission material on a black world, written as `<view>_mask.png`.
- Outputs under `work/art/<id>/blockout/` (created). Short procedures: the brief reading, one procedure per shape, the material, the figure, the cameras, the render, the mask render, `main`.

Verify: the command; the ten files; the hero read with the Read tool.

First run, 2026-10-18: the brief's grille, a solid box, hid the window, so the grille became three bars and a part's `blockout` may be a list of shapes; the ground sits at z 0, the hero is framed by a camera fit with a margin of a tenth, the masks render with the Standard transform and no dither and are thresholded at half after the render, since the pixel filter leaves grey edges (review).
