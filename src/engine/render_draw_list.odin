package engine

Mesh_Id :: distinct u32
Material_Id :: distinct u32

Directional_Light :: struct {
	direction, colour: [3]f32,
	intensity:         f32,
}

// Intensity as for the sun: what a white Lambert surface one metre away,
// facing the light, returns. Range is the distance where it reaches zero.
Point_Light :: struct {
	position, colour: [3]f32,
	intensity, range: f32,
}

Draw_Item :: struct {
	mesh:         Mesh_Id,
	material:     Material_Id,
	transform:    matrix[4, 4]f32,
	// The primitive's half extents in its local space, for the edge distance of the wear rule.
	half_extents: [3]f32,
}

// What a demo or module fills each frame and the renderer only reads.
Draw_List :: struct {
	camera:                    Camera,
	sun:                       Directional_Light,
	// Scales the linear scene colour before the tone map, 1 keeps it as is.
	exposure:                  f32,
	// The hemisphere the ambient term blends by the normal's height.
	sky_colour, ground_colour: [3]f32,
	items:                     [dynamic]Draw_Item,
	lights:                    [dynamic]Point_Light,
}

draw_list_add :: proc(list: ^Draw_List, mesh: Mesh_Id, material: Material_Id, transform: matrix[4, 4]f32, half_extents: [3]f32) {
	append(&list.items, Draw_Item{mesh = mesh, material = material, transform = transform, half_extents = half_extents})
}

draw_list_add_light :: proc(list: ^Draw_List, light: Point_Light) {
	append(&list.lights, light)
}

// Empties the list and keeps its capacity for the next frame.
draw_list_clear :: proc(list: ^Draw_List) {
	clear(&list.items)
	clear(&list.lights)
}

draw_list_destroy :: proc(list: ^Draw_List) {
	delete(list.items)
	list.items = nil
	delete(list.lights)
	list.lights = nil
}
