package engine

import "core:math/linalg"
import gl "glapi"

Gl_Mesh :: struct {
	vertex_array:                gl.VertexArrayObject,
	vertex_buffer, index_buffer: gl.Buffer,
	index_count:                 int,
}

Gl_Uniforms :: struct {
	model, view, projection, sun_direction, sun_colour, albedo:  i32,
	sky_colour, ground_colour, camera_position:                  i32,
	roughness, metallic, emissive:                               i32,
	point_light_count, point_light_position, point_light_colour: i32,
	point_light_range:                                           i32,
	has_textures, albedo_map, normal_map, surface_map:           i32,
	texture_metres:                                              i32,
	half_extents, wear_edge_width, wear_chip_threshold:          i32,
	wear_amount, wear_metal:                                     i32,
	dither_skip, tint:                                           i32,
}

Gl_Tonemap_Uniforms :: struct {
	scene, exposure, bloom, bloom_strength, bloom_levels: i32,
}

Gl_Downsample_Uniforms :: struct {
	source, texel, karis: i32,
}

Gl_Upsample_Uniforms :: struct {
	source, texel: i32,
}

// A half float colour target: the forward pass renders into one with depth, the bloom passes into a chain without.
Gl_Target :: struct {
	framebuffer:   gl.Framebuffer,
	colour:        gl.Texture,
	depth:         gl.Renderbuffer,
	width, height: i32,
}

// The uploaded images of a material's texture set; present is false for a material without one.
Gl_Texture_Set :: struct {
	albedo, normal, surface: gl.Texture,
	present:                 bool,
}

Gl_Renderer :: struct {
	program:          gl.Program,
	uniforms:         Gl_Uniforms,
	tonemap_program:  gl.Program,
	tonemap_uniforms: Gl_Tonemap_Uniforms,
	downsample_program:  gl.Program,
	downsample_uniforms: Gl_Downsample_Uniforms,
	upsample_program:    gl.Program,
	upsample_uniforms:   Gl_Upsample_Uniforms,
	target:              Gl_Target,
	// Level 0 is half the canvas, each next level half the previous; after the passes level 0 holds the bloom.
	bloom_targets:       [GL_RENDERER_BLOOM_LEVELS]Gl_Target,
	meshes:              [dynamic]Gl_Mesh,
	// Indexed by Material_Id.
	texture_sets:        [dynamic]Gl_Texture_Set,
	// Empty, bound for the post passes: they draw from gl_VertexID, and a
	// core profile has no default vertex array.
	fullscreen_vertex_array: gl.VertexArrayObject,
}

// Matches MAX_POINT_LIGHTS in forward.frag; lights beyond it are not drawn.
GL_RENDERER_MAX_POINT_LIGHTS :: 8

// The bloom chain's length, and the share of the bloom mixed into the scene before the tone map.
GL_RENDERER_BLOOM_LEVELS :: 5
GL_RENDERER_BLOOM_STRENGTH :: f32(0.05)

// The world size in metres one repeat of a texture set covers at the near scale.
// Equal to tile_metres of every bake file under data/materials/bake/, which
// scales the normal map's slopes; a per material value waits for a set that needs it.
GL_RENDERER_TEXTURE_METRES :: f32(2)

GL_RENDERER_VERTEX_SHADER :: #load("shaders/forward.vert", string)
GL_RENDERER_FRAGMENT_SHADER :: #load("shaders/forward.frag", string)
GL_RENDERER_TONEMAP_VERTEX_SHADER :: #load("shaders/tonemap.vert", string)
GL_RENDERER_TONEMAP_FRAGMENT_SHADER :: #load("shaders/tonemap.frag", string)
GL_RENDERER_DOWNSAMPLE_FRAGMENT_SHADER :: #load("shaders/downsample.frag", string)
GL_RENDERER_UPSAMPLE_FRAGMENT_SHADER :: #load("shaders/upsample.frag", string)

gl_renderer_init :: proc(renderer: ^Gl_Renderer) -> bool {
	program, compiled := gl.CreateProgramFromStrings({GL_RENDERER_VERTEX_SHADER}, {GL_RENDERER_FRAGMENT_SHADER})
	if !compiled {
		return false
	}
	renderer.program = program
	renderer.uniforms = Gl_Uniforms {
		model                = gl.GetUniformLocation(program, "model"),
		view                 = gl.GetUniformLocation(program, "view"),
		projection           = gl.GetUniformLocation(program, "projection"),
		sun_direction        = gl.GetUniformLocation(program, "sun_direction"),
		sun_colour           = gl.GetUniformLocation(program, "sun_colour"),
		sky_colour           = gl.GetUniformLocation(program, "sky_colour"),
		ground_colour        = gl.GetUniformLocation(program, "ground_colour"),
		albedo               = gl.GetUniformLocation(program, "albedo"),
		camera_position      = gl.GetUniformLocation(program, "camera_position"),
		roughness            = gl.GetUniformLocation(program, "roughness"),
		metallic             = gl.GetUniformLocation(program, "metallic"),
		emissive             = gl.GetUniformLocation(program, "emissive"),
		point_light_count    = gl.GetUniformLocation(program, "point_light_count"),
		point_light_position = gl.GetUniformLocation(program, "point_light_position"),
		point_light_colour   = gl.GetUniformLocation(program, "point_light_colour"),
		point_light_range    = gl.GetUniformLocation(program, "point_light_range"),
		has_textures         = gl.GetUniformLocation(program, "has_textures"),
		albedo_map           = gl.GetUniformLocation(program, "albedo_map"),
		normal_map           = gl.GetUniformLocation(program, "normal_map"),
		surface_map          = gl.GetUniformLocation(program, "surface_map"),
		texture_metres       = gl.GetUniformLocation(program, "texture_metres"),
		half_extents         = gl.GetUniformLocation(program, "half_extents"),
		wear_edge_width      = gl.GetUniformLocation(program, "wear_edge_width"),
		wear_chip_threshold  = gl.GetUniformLocation(program, "wear_chip_threshold"),
		wear_amount          = gl.GetUniformLocation(program, "wear_amount"),
		wear_metal           = gl.GetUniformLocation(program, "wear_metal"),
		dither_skip          = gl.GetUniformLocation(program, "dither_skip"),
		tint                 = gl.GetUniformLocation(program, "tint"),
	}
	// Set once: the texture units the material's maps bind to, and the near scale.
	gl.UseProgram(program)
	gl.Uniform1i(renderer.uniforms.albedo_map, 0)
	gl.Uniform1i(renderer.uniforms.normal_map, 1)
	gl.Uniform1i(renderer.uniforms.surface_map, 2)
	gl.Uniform1f(renderer.uniforms.texture_metres, GL_RENDERER_TEXTURE_METRES)
	tonemap_program, tonemap_compiled := gl.CreateProgramFromStrings(
		{GL_RENDERER_TONEMAP_VERTEX_SHADER},
		{GL_RENDERER_TONEMAP_FRAGMENT_SHADER},
	)
	if !tonemap_compiled {
		return false
	}
	renderer.tonemap_program = tonemap_program
	renderer.tonemap_uniforms = Gl_Tonemap_Uniforms {
		scene          = gl.GetUniformLocation(tonemap_program, "scene"),
		exposure       = gl.GetUniformLocation(tonemap_program, "exposure"),
		bloom          = gl.GetUniformLocation(tonemap_program, "bloom"),
		bloom_strength = gl.GetUniformLocation(tonemap_program, "bloom_strength"),
		bloom_levels   = gl.GetUniformLocation(tonemap_program, "bloom_levels"),
	}
	downsample_program, downsample_compiled := gl.CreateProgramFromStrings(
		{GL_RENDERER_TONEMAP_VERTEX_SHADER},
		{GL_RENDERER_DOWNSAMPLE_FRAGMENT_SHADER},
	)
	if !downsample_compiled {
		return false
	}
	renderer.downsample_program = downsample_program
	renderer.downsample_uniforms = Gl_Downsample_Uniforms {
		source = gl.GetUniformLocation(downsample_program, "source"),
		texel  = gl.GetUniformLocation(downsample_program, "texel"),
		karis  = gl.GetUniformLocation(downsample_program, "karis"),
	}
	upsample_program, upsample_compiled := gl.CreateProgramFromStrings(
		{GL_RENDERER_TONEMAP_VERTEX_SHADER},
		{GL_RENDERER_UPSAMPLE_FRAGMENT_SHADER},
	)
	if !upsample_compiled {
		return false
	}
	renderer.upsample_program = upsample_program
	renderer.upsample_uniforms = Gl_Upsample_Uniforms {
		source = gl.GetUniformLocation(upsample_program, "source"),
		texel  = gl.GetUniformLocation(upsample_program, "texel"),
	}
	// Needed once before an RGBA16F colour attachment renders.
	gl.GetExtension("EXT_color_buffer_float")
	renderer.fullscreen_vertex_array = gl.CreateVertexArray()
	return true
}

// Deletes every GL object the renderer made, frees its lists and zeroes it.
gl_renderer_destroy :: proc(renderer: ^Gl_Renderer) {
	gl.DeleteProgram(renderer.program)
	gl.DeleteProgram(renderer.tonemap_program)
	gl.DeleteProgram(renderer.downsample_program)
	gl.DeleteProgram(renderer.upsample_program)
	for mesh in renderer.meshes {
		gl.DeleteVertexArray(mesh.vertex_array)
		gl.DeleteBuffer(mesh.vertex_buffer)
		gl.DeleteBuffer(mesh.index_buffer)
	}
	for set in renderer.texture_sets {
		if !set.present do continue
		gl.DeleteTexture(set.albedo)
		gl.DeleteTexture(set.normal)
		gl.DeleteTexture(set.surface)
	}
	gl_renderer_target_destroy(&renderer.target)
	for &target in renderer.bloom_targets {
		gl_renderer_target_destroy(&target)
	}
	gl.DeleteVertexArray(renderer.fullscreen_vertex_array)
	delete(renderer.meshes)
	delete(renderer.texture_sets)
	renderer^ = {}
}

gl_renderer_upload_mesh :: proc(renderer: ^Gl_Renderer, mesh: Mesh_Data) -> Mesh_Id {
	uploaded := Gl_Mesh {
		vertex_array  = gl.CreateVertexArray(),
		vertex_buffer = gl.CreateBuffer(),
		index_buffer  = gl.CreateBuffer(),
		index_count   = len(mesh.indices),
	}
	gl.BindVertexArray(uploaded.vertex_array)
	gl.BindBuffer(gl.ARRAY_BUFFER, uploaded.vertex_buffer)
	gl.BufferDataSlice(gl.ARRAY_BUFFER, mesh.vertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, uploaded.index_buffer)
	gl.BufferDataSlice(gl.ELEMENT_ARRAY_BUFFER, mesh.indices, gl.STATIC_DRAW)
	gl.BindVertexArray(0)
	append(&renderer.meshes, uploaded)
	return Mesh_Id(len(renderer.meshes) - 1)
}

// Stores the set at the material's index, growing the list to cover it.
gl_renderer_upload_texture_set :: proc(renderer: ^Gl_Renderer, material: Material_Id, set: Texture_Set_Data) {
	if int(material) >= len(renderer.texture_sets) {
		resize(&renderer.texture_sets, int(material) + 1)
	}
	renderer.texture_sets[material] = Gl_Texture_Set {
		albedo  = gl_renderer_upload_image(set.albedo, true),
		normal  = gl_renderer_upload_image(set.normal, false),
		surface = gl_renderer_upload_image(set.surface, false),
		present = true,
	}
}

// A mipmapped, repeating texture; srgb decodes the colour to linear on sampling.
@(private = "file")
gl_renderer_upload_image :: proc(image: Image_Data, srgb: bool) -> gl.Texture {
	texture := gl.CreateTexture()
	internal_format := gl.SRGB8_ALPHA8 if srgb else gl.RGBA8
	gl.BindTexture(gl.TEXTURE_2D, texture)
	// The PNG holds the top row first; flipped, t runs upward, which the normal map's +Y assumes.
	gl.PixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 1)
	gl.TexImage2DSlice(gl.TEXTURE_2D, 0, internal_format, i32(image.width), i32(image.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, image.pixels)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR_MIPMAP_LINEAR))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.LINEAR))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.REPEAT))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.REPEAT))
	gl.BindTexture(gl.TEXTURE_2D, 0)
	return texture
}

// Deletes the target's handles, if it was ever created, and zeroes it.
gl_renderer_target_destroy :: proc(target: ^Gl_Target) {
	if target.framebuffer != 0 {
		gl.DeleteTexture(target.colour)
		if target.depth != 0 {
			gl.DeleteRenderbuffer(target.depth)
		}
		gl.DeleteFramebuffer(target.framebuffer)
	}
	target^ = {}
}

// (Re)creates the target when the size differs, deleting the old handles.
// The depth renderbuffer exists only with_depth; linear picks LINEAR over NEAREST filtering.
gl_renderer_target_ensure :: proc(target: ^Gl_Target, width, height: i32, with_depth, linear: bool) {
	if target.framebuffer != 0 && target.width == width && target.height == height {
		return
	}
	gl_renderer_target_destroy(target)
	target^ = Gl_Target {
		framebuffer = gl.CreateFramebuffer(),
		colour      = gl.CreateTexture(),
		width       = width,
		height      = height,
	}
	filter := i32(gl.LINEAR) if linear else i32(gl.NEAREST)
	gl.BindTexture(gl.TEXTURE_2D, target.colour)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, width, height, 0, gl.RGBA, gl.HALF_FLOAT, 0, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
	gl.BindFramebuffer(gl.FRAMEBUFFER, target.framebuffer)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target.colour, 0)
	if with_depth {
		target.depth = gl.CreateRenderbuffer()
		gl.BindRenderbuffer(gl.RENDERBUFFER, target.depth)
		gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, width, height)
		gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, target.depth)
	}
	// Left bound on the active unit, the new colour texture would feed back into the
	// forward pass, whose samplers sit on the units 0 to 2.
	gl.BindTexture(gl.TEXTURE_2D, 0)
}

// Draws the fullscreen triangle into the framebuffer; the caller sets the program, textures and uniforms.
gl_renderer_draw_fullscreen :: proc(renderer: ^Gl_Renderer, framebuffer: gl.Framebuffer, width, height: i32, x: i32 = 0, y: i32 = 0) {
	gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer)
	gl.Viewport(x, y, width, height)
	gl.BindVertexArray(renderer.fullscreen_vertex_array)
	gl.DrawArrays(gl.TRIANGLES, 0, 3)
}

// The 13 tap downsample of source into destination; karis on the first level only.
gl_renderer_downsample_pass :: proc(renderer: ^Gl_Renderer, source, destination: Gl_Target, karis: bool) {
	uniforms := renderer.downsample_uniforms
	gl.UseProgram(renderer.downsample_program)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, source.colour)
	gl.Uniform1i(uniforms.source, 0)
	gl.Uniform2f(uniforms.texel, 1 / f32(source.width), 1 / f32(source.height))
	gl.Uniform1i(uniforms.karis, 1 if karis else 0)
	gl_renderer_draw_fullscreen(renderer, destination.framebuffer, destination.width, destination.height)
}

// The tent upsample of source drawn into destination; the caller sets additive blending.
gl_renderer_upsample_pass :: proc(renderer: ^Gl_Renderer, source, destination: Gl_Target) {
	uniforms := renderer.upsample_uniforms
	gl.UseProgram(renderer.upsample_program)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, source.colour)
	gl.Uniform1i(uniforms.source, 0)
	gl.Uniform2f(uniforms.texel, 1 / f32(source.width), 1 / f32(source.height))
	gl_renderer_draw_fullscreen(renderer, destination.framebuffer, destination.width, destination.height)
}

// Downsamples the scene down the chain, then adds each level into the next larger one, leaving the bloom in level 0.
gl_renderer_bloom_passes :: proc(renderer: ^Gl_Renderer) {
	levels := renderer.bloom_targets
	gl_renderer_downsample_pass(renderer, renderer.target, levels[0], true)
	for level in 1 ..< GL_RENDERER_BLOOM_LEVELS {
		gl_renderer_downsample_pass(renderer, levels[level - 1], levels[level], false)
	}
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.ONE, gl.ONE)
	for level := GL_RENDERER_BLOOM_LEVELS - 1; level >= 1; level -= 1 {
		gl_renderer_upsample_pass(renderer, levels[level], levels[level - 1])
	}
	gl.Disable(gl.BLEND)
}

// Tone maps the scene colour mixed with the bloom to the canvas.
gl_renderer_tonemap_pass :: proc(renderer: ^Gl_Renderer, exposure: f32, width, height, x, y: i32) {
	uniforms := renderer.tonemap_uniforms
	gl.UseProgram(renderer.tonemap_program)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, renderer.target.colour)
	gl.Uniform1i(uniforms.scene, 0)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, renderer.bloom_targets[0].colour)
	gl.Uniform1i(uniforms.bloom, 1)
	gl.Uniform1f(uniforms.exposure, exposure)
	gl.Uniform1f(uniforms.bloom_strength, GL_RENDERER_BLOOM_STRENGTH)
	gl.Uniform1f(uniforms.bloom_levels, f32(GL_RENDERER_BLOOM_LEVELS))
	gl_renderer_draw_fullscreen(renderer, gl.Framebuffer(0), width, height, x, y)
	// Unbound so the next forward pass never samples its own target.
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, 0)
}

// Uploads the first GL_RENDERER_MAX_POINT_LIGHTS lights, colour times intensity.
gl_renderer_upload_point_lights :: proc(uniforms: Gl_Uniforms, lights: []Point_Light) {
	count := min(len(lights), GL_RENDERER_MAX_POINT_LIGHTS)
	gl.Uniform1i(uniforms.point_light_count, i32(count))
	if count == 0 {
		return
	}
	positions, colours: [GL_RENDERER_MAX_POINT_LIGHTS][3]f32
	ranges: [GL_RENDERER_MAX_POINT_LIGHTS]f32
	for light, index in lights[:count] {
		positions[index] = light.position
		colours[index] = light.colour * light.intensity
		// A range at or below zero would divide by zero or raise a negative base in the shader.
		ranges[index] = max(light.range, 0.001)
	}
	gl.Uniform3fv(uniforms.point_light_position, positions[:count])
	gl.Uniform3fv(uniforms.point_light_colour, colours[:count])
	gl.Uniform1fv(uniforms.point_light_range, ranges[:count])
}

gl_renderer_draw :: proc(renderer: ^Gl_Renderer, list: Draw_List, library: Material_Library, width, height: i32) {
	gl_renderer_draw_viewport(renderer, list, library, 0, 0, width, height)
}

// The scene drawn at the rectangle's size and composited into that rectangle of
// the window, x and y its bottom left corner in window pixels, so several views
// share one window. The targets follow the size of the last rectangle drawn.
gl_renderer_draw_viewport :: proc(renderer: ^Gl_Renderer, list: Draw_List, library: Material_Library, x, y, width, height: i32) {
	if width <= 0 || height <= 0 {
		return
	}
	// Linear, so the first downsample's taps average two by two scene texels.
	gl_renderer_target_ensure(&renderer.target, width, height, true, true)
	level_width, level_height := width, height
	for &level in renderer.bloom_targets {
		level_width, level_height = max(level_width / 2, 1), max(level_height / 2, 1)
		gl_renderer_target_ensure(&level, level_width, level_height, false, true)
	}
	// The forward pass's state, set every frame: a host such as raylib draws
	// its own between frames.
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)
	gl.Enable(gl.CULL_FACE)
	gl.FrontFace(gl.CCW)
	gl.Disable(gl.BLEND)
	gl.BindFramebuffer(gl.FRAMEBUFFER, renderer.target.framebuffer)
	gl.Viewport(0, 0, width, height)
	// Linear, so it passes the tone map: it displays close to (0.05, 0.06, 0.08).
	gl.ClearColor(0.004, 0.005, 0.007, 1)
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		gl.BindFramebuffer(gl.FRAMEBUFFER, gl.Framebuffer(0))
		gl.Clear(u32(gl.COLOR_BUFFER_BIT) | u32(gl.DEPTH_BUFFER_BIT))
		return
	}
	gl.Clear(u32(gl.COLOR_BUFFER_BIT) | u32(gl.DEPTH_BUFFER_BIT))
	gl.UseProgram(renderer.program)
	uniforms := renderer.uniforms
	aspect := f32(width) / f32(max(height, 1))
	gl.UniformMatrix4fv(uniforms.view, view_matrix(list.camera))
	gl.UniformMatrix4fv(uniforms.projection, projection_matrix(list.camera, aspect))
	sun_direction := linalg.normalize(list.sun.direction)
	sun_colour := list.sun.colour * list.sun.intensity
	gl.Uniform3f(uniforms.sun_direction, sun_direction.x, sun_direction.y, sun_direction.z)
	gl.Uniform3f(uniforms.sun_colour, sun_colour.r, sun_colour.g, sun_colour.b)
	gl.Uniform3f(uniforms.sky_colour, list.sky_colour.r, list.sky_colour.g, list.sky_colour.b)
	gl.Uniform3f(uniforms.ground_colour, list.ground_colour.r, list.ground_colour.g, list.ground_colour.b)
	camera_position := list.camera.position
	gl.Uniform3f(uniforms.camera_position, camera_position.x, camera_position.y, camera_position.z)
	gl_renderer_upload_point_lights(uniforms, list.lights[:])
	for item in list.items {
		if int(item.material) >= len(library.materials) || int(item.mesh) >= len(renderer.meshes) {
			continue
		}
		material := library.materials[item.material]
		albedo := material.albedo
		emissive := material.emissive
		mesh := renderer.meshes[item.mesh]
		gl.Uniform3f(uniforms.albedo, albedo.r, albedo.g, albedo.b)
		gl.Uniform1f(uniforms.roughness, material.roughness)
		gl.Uniform1f(uniforms.metallic, material.metallic)
		gl.Uniform3f(uniforms.emissive, emissive.r, emissive.g, emissive.b)
		gl_renderer_bind_material_textures(renderer, uniforms, item.material)
		gl_renderer_upload_wear(uniforms, item, material)
		gl.Uniform2f(uniforms.dither_skip, item.dither_skip.x, item.dither_skip.y)
		gl.Uniform3f(uniforms.tint, item.tint.r, item.tint.g, item.tint.b)
		gl.UniformMatrix4fv(uniforms.model, item.transform)
		gl.BindVertexArray(mesh.vertex_array)
		gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
	}
	gl.Disable(gl.DEPTH_TEST)
	gl_renderer_bloom_passes(renderer)
	gl_renderer_tonemap_pass(renderer, list.exposure, width, height, x, y)
}

// Binds the material's texture set to the units 0 to 2, or tells the shader it has none.
@(private = "file")
gl_renderer_bind_material_textures :: proc(renderer: ^Gl_Renderer, uniforms: Gl_Uniforms, material: Material_Id) {
	if int(material) >= len(renderer.texture_sets) || !renderer.texture_sets[material].present {
		gl.Uniform1i(uniforms.has_textures, 0)
		return
	}
	set := renderer.texture_sets[material]
	textures := [3]gl.Texture{set.albedo, set.normal, set.surface}
	for texture, unit in textures {
		gl.ActiveTexture(gl.TEXTURE0 + gl.Enum(unit))
		gl.BindTexture(gl.TEXTURE_2D, texture)
	}
	gl.Uniform1i(uniforms.has_textures, 1)
}

// The item's half extents and the material's wear rule for the forward shader.
@(private = "file")
gl_renderer_upload_wear :: proc(uniforms: Gl_Uniforms, item: Draw_Item, material: Material) {
	half_extents := item.half_extents
	wear := material.wear
	gl.Uniform3f(uniforms.half_extents, half_extents.x, half_extents.y, half_extents.z)
	gl.Uniform1f(uniforms.wear_edge_width, wear.edge_width)
	gl.Uniform1f(uniforms.wear_chip_threshold, wear.chip_threshold)
	gl.Uniform1f(uniforms.wear_amount, wear.amount)
	gl.Uniform3f(uniforms.wear_metal, wear.metal.r, wear.metal.g, wear.metal.b)
}
