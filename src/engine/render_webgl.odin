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
}

Webgl_Renderer :: struct {
	program:  gl.Program,
	uniforms: Webgl_Uniforms,
	meshes:   [dynamic]Webgl_Mesh,
}

// A constant ambient term until the sky ambient of stage 1 replaces it.
WEBGL_AMBIENT :: 0.15

WEBGL_VERTEX_SHADER :: `#version 300 es
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
out vec3 world_normal;
void main() {
	// Assumes a uniform scale in the model matrix.
	world_normal = mat3(model) * normal;
	gl_Position = projection * view * model * vec4(position, 1.0);
}
`

WEBGL_FRAGMENT_SHADER :: `#version 300 es
precision mediump float;
uniform vec3 sun_direction;
uniform vec3 sun_colour;
uniform float ambient;
uniform vec3 albedo;
in vec3 world_normal;
out vec4 colour;
void main() {
	// sun_direction is the direction the light travels.
	float diffuse = max(dot(normalize(world_normal), -sun_direction), 0.0);
	vec3 linear = albedo * (ambient + diffuse * sun_colour);
	colour = vec4(pow(linear, vec3(1.0 / 2.2)), 1.0);
}
`

webgl_renderer_init :: proc(renderer: ^Webgl_Renderer) -> bool {
	program, compiled := gl.CreateProgramFromStrings({WEBGL_VERTEX_SHADER}, {WEBGL_FRAGMENT_SHADER})
	if !compiled {
		return false
	}
	renderer.program = program
	renderer.uniforms = Webgl_Uniforms {
		model         = gl.GetUniformLocation(program, "model"),
		view          = gl.GetUniformLocation(program, "view"),
		projection    = gl.GetUniformLocation(program, "projection"),
		sun_direction = gl.GetUniformLocation(program, "sun_direction"),
		sun_colour    = gl.GetUniformLocation(program, "sun_colour"),
		ambient       = gl.GetUniformLocation(program, "ambient"),
		albedo        = gl.GetUniformLocation(program, "albedo"),
	}
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

webgl_renderer_draw :: proc(renderer: ^Webgl_Renderer, list: Draw_List, library: Material_Library, width, height: i32) {
	gl.Viewport(0, 0, width, height)
	gl.ClearColor(0.05, 0.06, 0.08, 1)
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
	for item in list.items {
		if int(item.material) >= len(library.materials) || int(item.mesh) >= len(renderer.meshes) {
			continue
		}
		albedo := library.materials[item.material].albedo
		mesh := renderer.meshes[item.mesh]
		gl.Uniform3f(uniforms.albedo, albedo.r, albedo.g, albedo.b)
		gl.UniformMatrix4fv(uniforms.model, item.transform)
		gl.BindVertexArray(mesh.vertex_array)
		gl.DrawElements(gl.TRIANGLES, mesh.index_count, gl.UNSIGNED_INT, nil)
	}
}
