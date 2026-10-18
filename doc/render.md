# Rendering

The engine's render data in `src/engine/render_*.odin`: the draw list, the camera and the primitive meshes. The WebGL side that reads them comes later.

## The draw list

`Draw_List` carries a `Camera`, a sun (`Directional_Light`: direction, colour, intensity) and the draw items, each a mesh id, a material id and a transform matrix. Demos and modules fill it every frame with `draw_list_add`, empty it with `draw_list_clear` (which keeps the capacity) and free it with `draw_list_destroy`. The renderer only reads it.

## Conventions

Metres, y up, right handed, OpenGL clip space (`core:math/linalg` with its `flip_z_axis` default, near maps to -1 and far to 1), counter clockwise front faces seen from outside. A `Camera` holds its position, target and up vector, the vertical field of view in radians and the near and far planes. `view_matrix` and `projection_matrix` (given the aspect) build its matrices. `orbit_camera` places one around a target from an `Orbit`: yaw about y measured from +z, pitch up from the xz plane, and the distance, with up along y.

## Primitive meshes

`box_mesh(size)` is centred at the origin: six faces of four vertices carrying the face normal, 24 vertices and 36 indices. `cylinder_mesh(radius, height, segments)` runs along y, centred at the origin: two side rings of `segments + 1` vertices (the seam vertex repeated) with radial normals, and two caps of one centre and `segments` ring vertices with the cap normal, so `4 * (segments + 1)` vertices and `12 * segments` indices. Both return `Mesh_Data` (vertices of position and normal, `u32` indices), freed with `mesh_data_destroy`.

## Materials

`data/materials/library.sjson` is the material library every demo and module shares (embedded with `#load`), one object per material with the keys `albedo` (three numbers, 0 to 1), `roughness` (0 to 1), `metallic` (0 to 1) and the optional `emissive` (three numbers, 0 or more, default zero). Albedo is the paint or surface colour for a dielectric (`metallic = 0`) and the reflectance colour for a metal (`metallic = 1`). `parse_material_library` in `src/engine/material.odin` reads it into a `Material_Library` and rejects an unknown key, a missing key and a value out of range with a problem naming the material and the key, and `material_library_destroy` frees it. The `Material_Id` of a material is its index in alphabetical order of name, because the parsed SJSON object is a map without order and the ids must not change from one run to the next. `material_id_by_name` looks one up.
