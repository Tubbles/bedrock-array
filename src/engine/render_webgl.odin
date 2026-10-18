#+build js wasm32
package engine

import "core:math/linalg"
import gl "vendor:wasm/WebGL"

Webgl_Mesh :: struct {
	vertex_array:                gl.VertexArrayObject,
	vertex_buffer, index_buffer: gl.Buffer,
	index_count:                 int,
}

Webgl_Uniforms :: struct {
	model, view, projection, sun_direction, sun_colour, ambient, albedo: i32,
	camera_position, roughness, metallic, emissive:                      i32,
}

Webgl_Tonemap_Uniforms :: struct {
	scene, exposure: i32,
}

// The half float colour target the forward pass renders into.
Webgl_Target :: struct {
	framebuffer:   gl.Framebuffer,
	colour:        gl.Texture,
	depth:         gl.Renderbuffer,
	width, height: i32,
}

Webgl_Renderer :: struct {
	program:          gl.Program,
	uniforms:         Webgl_Uniforms,
	tonemap_program:  gl.Program,
	tonemap_uniforms: Webgl_Tonemap_Uniforms,
	target:           Webgl_Target,
	meshes:           [dynamic]Webgl_Mesh,
}

// A constant ambient term until the sky ambient of stage 1 replaces it.
WEBGL_AMBIENT :: 0.15

WEBGL_VERTEX_SHADER :: #load("shaders/forward.vert", string)
WEBGL_FRAGMENT_SHADER :: #load("shaders/forward.frag", string)
WEBGL_TONEMAP_VERTEX_SHADER :: #load("shaders/tonemap.vert", string)
WEBGL_TONEMAP_FRAGMENT_SHADER :: #load("shaders/tonemap.frag", string)

webgl_renderer_init :: proc(renderer: ^Webgl_Renderer) -> bool {
	program, compiled := gl.CreateProgramFromStrings({WEBGL_VERTEX_SHADER}, {WEBGL_FRAGMENT_SHADER})
	if !compiled {
		return false
	}
	renderer.program = program
	renderer.uniforms = Webgl_Uniforms {
		model           = gl.GetUniformLocation(program, "model"),
		view            = gl.GetUniformLocation(program, "view"),
		projection      = gl.GetUniformLocation(program, "projection"),
		sun_direction   = gl.GetUniformLocation(program, "sun_direction"),
		sun_colour      = gl.GetUniformLocation(program, "sun_colour"),
		ambient         = gl.GetUniformLocation(program, "ambient"),
		albedo          = gl.GetUniformLocation(program, "albedo"),
		camera_position = gl.GetUniformLocation(program, "camera_position"),
		roughness       = gl.GetUniformLocation(program, "roughness"),
		metallic        = gl.GetUniformLocation(program, "metallic"),
		emissive        = gl.GetUniformLocation(program, "emissive"),
	}
	tonemap_program, tonemap_compiled := gl.CreateProgramFromStrings(
		{WEBGL_TONEMAP_VERTEX_SHADER},
		{WEBGL_TONEMAP_FRAGMENT_SHADER},
	)
	if !tonemap_compiled {
		return false
	}
	renderer.tonemap_program = tonemap_program
	renderer.tonemap_uniforms = Webgl_Tonemap_Uniforms {
		scene    = gl.GetUniformLocation(tonemap_program, "scene"),
		exposure = gl.GetUniformLocation(tonemap_program, "exposure"),
	}
	// Needed once before an RGBA16F colour attachment renders.
	gl.GetExtension("EXT_color_buffer_float")
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
	gl.FrontFace(gl.CCW)
	gl.DepthFunc(gl.LEQUAL)
	return true
}

webgl_renderer_upload_mesh :: proc(renderer: ^Webgl_Renderer, mesh: Mesh_Data) -> Mesh_Id {
	uploaded := Webgl_Mesh {
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

// (Re)creates the target when the size differs, deleting the old handles.
webgl_target_ensure :: proc(renderer: ^Webgl_Renderer, width, height: i32) {
	target := &renderer.target
	if target.framebuffer != 0 && target.width == width && target.height == height {
		return
	}
	if target.framebuffer != 0 {
		gl.DeleteTexture(target.colour)
		gl.DeleteRenderbuffer(target.depth)
		gl.DeleteFramebuffer(target.framebuffer)
	}
	target^ = Webgl_Target {
		framebuffer = gl.CreateFramebuffer(),
		colour      = gl.CreateTexture(),
		depth       = gl.CreateRenderbuffer(),
		width       = width,
		height      = height,
	}
	gl.BindTexture(gl.TEXTURE_2D, target.colour)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, width, height, 0, gl.RGBA, gl.HALF_FLOAT, 0, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
	gl.BindRenderbuffer(gl.RENDERBUFFER, target.depth)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT24, width, height)
	gl.BindFramebuffer(gl.FRAMEBUFFER, target.framebuffer)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target.colour, 0)
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, target.depth)
}

webgl_renderer_draw :: proc(renderer: ^Webgl_Renderer, list: Draw_List, library: Material_Library, width, height: i32) {
	if width <= 0 || height <= 0 {
		return
	}
	webgl_target_ensure(renderer, width, height)
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
	gl.Uniform1f(uniforms.ambient, WEBGL_AMBIENT)
	camera_position := list.camera.position
	gl.Uniform3f(uniforms.camera_position, camera_position.x, camera_position.y, camera_position.z)
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
		gl.UniformMatrix4fv(uniforms.model, item.transform)
		gl.BindVertexArray(mesh.vertex_array)
		gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
	}
	gl.BindFramebuffer(gl.FRAMEBUFFER, gl.Framebuffer(0))
	gl.Viewport(0, 0, width, height)
	gl.Disable(gl.DEPTH_TEST)
	gl.UseProgram(renderer.tonemap_program)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, renderer.target.colour)
	gl.Uniform1i(renderer.tonemap_uniforms.scene, 0)
	gl.Uniform1f(renderer.tonemap_uniforms.exposure, list.exposure)
	gl.BindVertexArray(0)
	gl.DrawArrays(gl.TRIANGLES, 0, 3)
	// Unbound so the next forward pass never samples its own target.
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.Enable(gl.DEPTH_TEST)
}
