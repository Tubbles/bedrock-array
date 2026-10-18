# Rendering

The engine's render data in `src/engine/render_*.odin`: the draw list, the camera and the primitive meshes. `render_webgl.odin` is the WebGL2 renderer that reads them in the browser.

## The draw list

`Draw_List` carries a `Camera`, a sun (`Directional_Light`: direction, colour, intensity) and the draw items, each a mesh id, a material id and a transform matrix. Demos and modules fill it every frame with `draw_list_add`, empty it with `draw_list_clear` (which keeps the capacity) and free it with `draw_list_destroy`. The renderer only reads it.

## Conventions

Metres, y up, right handed, OpenGL clip space (`core:math/linalg` with its `flip_z_axis` default, near maps to -1 and far to 1), counter clockwise front faces seen from outside. A `Camera` holds its position, target and up vector, the vertical field of view in radians and the near and far planes. `view_matrix` and `projection_matrix` (given the aspect) build its matrices. `orbit_camera` places one around a target from an `Orbit`: yaw about y measured from +z, pitch up from the xz plane, and the distance, with up along y.

## Primitive meshes

`box_mesh(size)` is centred at the origin: six faces of four vertices carrying the face normal, 24 vertices and 36 indices. `cylinder_mesh(radius, height, segments)` runs along y, centred at the origin: two side rings of `segments + 1` vertices (the seam vertex repeated) with radial normals, and two caps of one centre and `segments` ring vertices with the cap normal, so `4 * (segments + 1)` vertices and `12 * segments` indices. Both return `Mesh_Data` (vertices of position and normal, `u32` indices), freed with `mesh_data_destroy`.

## Materials

`data/materials/library.sjson` is the material library every demo and module shares (embedded with `#load`), one object per material with the keys `albedo` (three numbers, 0 to 1), `roughness` (0 to 1), `metallic` (0 to 1) and the optional `emissive` (three numbers, 0 or more, default zero). Albedo is the paint or surface colour for a dielectric (`metallic = 0`) and the reflectance colour for a metal (`metallic = 1`). `parse_material_library` in `src/engine/material.odin` reads it into a `Material_Library` and rejects an unknown key, a missing key and a value out of range with a problem naming the material and the key, and `material_library_destroy` frees it. The `Material_Id` of a material is its index in alphabetical order of name, because the parsed SJSON object is a map without order and the ids must not change from one run to the next. `material_id_by_name` looks one up.

## The WebGL2 renderer

`src/engine/render_webgl.odin` carries `#+build js wasm32`, so it belongs to the `engine` package for the browser target only. `webgl_renderer_init` compiles and links one GLSL ES 3.00 program and enables the depth test (`LEQUAL`) and back face culling with counter clockwise front faces. `webgl_renderer_upload_mesh` uploads a `Mesh_Data` once into a vertex array (attribute 0 the position, attribute 1 the normal, `u32` indices) and returns its `Mesh_Id`, the index in upload order. `webgl_renderer_draw` clears the canvas and issues one draw call per item of the `Draw_List`, skipping an item whose mesh or material id is out of range. The shading today is Lambert diffuse from the sun plus a constant ambient (`WEBGL_AMBIENT`), multiplied by the material's albedo, with gamma 2.2 applied at the end. Stage 1 replaces the shading with physically based shading, the constant with the sky ambient, and the gamma output with HDR and tone mapping. The sun direction is the direction the light travels, towards the scene, so a sun overhead points down. The normal is transformed with `mat3(model)`, which assumes a uniform scale in the model matrix.
