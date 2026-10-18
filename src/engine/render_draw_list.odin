package engine

Mesh_Id :: distinct u32
Material_Id :: distinct u32

Directional_Light :: struct {
	direction, colour: [3]f32,
	intensity:         f32,
}

Draw_Item :: struct {
	mesh:      Mesh_Id,
	material:  Material_Id,
	transform: matrix[4, 4]f32,
}

// What a demo or module fills each frame and the renderer only reads.
Draw_List :: struct {
	camera:   Camera,
	sun:      Directional_Light,
	// Scales the linear scene colour before the tone map, 1 keeps it as is.
	exposure: f32,
	items:    [dynamic]Draw_Item,
}

draw_list_add :: proc(list: ^Draw_List, mesh: Mesh_Id, material: Material_Id, transform: matrix[4, 4]f32) {
	append(&list.items, Draw_Item{mesh = mesh, material = material, transform = transform})
}

// Empties the list and keeps its capacity for the next frame.
draw_list_clear :: proc(list: ^Draw_List) {
	clear(&list.items)
}

draw_list_destroy :: proc(list: ^Draw_List) {
	delete(list.items)
	list.items = nil
}
