#+build !js
// The GL names the renderer draws through, mapped to desktop OpenGL 3.3
// with the WebGL binding's signatures, so the renderer compiles unchanged.
// The procedures are valid once the app has run gl.load_up_to.
package glapi

import "core:fmt"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"

// Types
Enum :: u32
Buffer :: u32
Texture :: u32
Program :: u32
Framebuffer :: u32
Renderbuffer :: u32
VertexArrayObject :: u32

// Procedures
ActiveTexture :: gl.ActiveTexture
BindBuffer :: gl.BindBuffer
BindFramebuffer :: gl.BindFramebuffer
BindRenderbuffer :: gl.BindRenderbuffer
BindTexture :: gl.BindTexture
BindVertexArray :: gl.BindVertexArray
BlendFunc :: gl.BlendFunc

BufferDataSlice :: proc(target: Enum, slice: $S/[]$E, usage: Enum) {
	gl.BufferData(target, len(slice) * size_of(E), raw_data(slice), usage)
}

CheckFramebufferStatus :: gl.CheckFramebufferStatus
Clear :: gl.Clear
ClearColor :: gl.ClearColor

CreateBuffer :: proc() -> Buffer {
	buffer: u32
	gl.GenBuffers(1, &buffer)
	return buffer
}

CreateFramebuffer :: proc() -> Framebuffer {
	framebuffer: u32
	gl.GenFramebuffers(1, &framebuffer)
	return framebuffer
}

// Concatenates each list, swaps the version line for the desktop one and links.
CreateProgramFromStrings :: proc(vs_sources, fs_sources: []string) -> (Program, bool) {
	vertex_source := shader_source_for_desktop(strings.concatenate(vs_sources, context.temp_allocator), context.temp_allocator)
	fragment_source := shader_source_for_desktop(strings.concatenate(fs_sources, context.temp_allocator), context.temp_allocator)
	program, linked := gl.load_shaders_source(vertex_source, fragment_source)
	if !linked {
		compile_message, _, link_message, _ := gl.get_last_error_messages()
		fmt.eprintln("shader program did not build:", compile_message, link_message)
	}
	return program, linked
}

CreateRenderbuffer :: proc() -> Renderbuffer {
	renderbuffer: u32
	gl.GenRenderbuffers(1, &renderbuffer)
	return renderbuffer
}

CreateTexture :: proc() -> Texture {
	texture: u32
	gl.GenTextures(1, &texture)
	return texture
}

CreateVertexArray :: proc() -> VertexArrayObject {
	vertex_array: u32
	gl.GenVertexArrays(1, &vertex_array)
	return vertex_array
}

DeleteFramebuffer :: proc(framebuffer: Framebuffer) {
	handle := framebuffer
	gl.DeleteFramebuffers(1, &handle)
}

DeleteRenderbuffer :: proc(renderbuffer: Renderbuffer) {
	handle := renderbuffer
	gl.DeleteRenderbuffers(1, &handle)
}

DeleteTexture :: proc(texture: Texture) {
	handle := texture
	gl.DeleteTextures(1, &handle)
}

DepthFunc :: gl.DepthFunc
Disable :: gl.Disable

DrawArrays :: proc(mode: Enum, first, count: int) {
	gl.DrawArrays(mode, i32(first), i32(count))
}

DrawElements :: proc(mode: Enum, count: int, type: Enum, indices: rawptr) {
	gl.DrawElements(mode, i32(count), type, indices)
}

Enable :: gl.Enable

EnableVertexAttribArray :: proc(index: i32) {
	gl.EnableVertexAttribArray(u32(index))
}

FramebufferRenderbuffer :: gl.FramebufferRenderbuffer
FramebufferTexture2D :: gl.FramebufferTexture2D
FrontFace :: gl.FrontFace
GenerateMipmap :: gl.GenerateMipmap

// Half float colour attachments are core in 3.3, nothing to enable.
GetExtension :: proc(name: string) {}

GetUniformLocation :: proc(program: Program, name: string) -> i32 {
	return gl.GetUniformLocation(program, strings.clone_to_cstring(name, context.temp_allocator))
}

// UNPACK_FLIP_Y_WEBGL has no desktop counterpart: TexImage2DSlice honours it.
PixelStorei :: proc(pname: Enum, param: i32) {
	if pname == UNPACK_FLIP_Y_WEBGL {
		flip_y = param != 0
		return
	}
	gl.PixelStorei(pname, param)
}

RenderbufferStorage :: gl.RenderbufferStorage

TexImage2D :: proc(target: Enum, level: i32, internalformat: Enum, width, height: i32, border: i32, format, type: Enum, size: int, data: rawptr) {
	gl.TexImage2D(target, level, i32(internalformat), width, height, border, format, type, data)
}

TexImage2DSlice :: proc(target: Enum, level: i32, internalformat: Enum, width, height: i32, border: i32, format, type: Enum, slice: $S/[]$E) {
	bytes := mem.slice_to_bytes(slice)
	if flip_y {
		bytes = rows_reversed(bytes, int(height), context.temp_allocator)
	}
	gl.TexImage2D(target, level, i32(internalformat), width, height, border, format, type, raw_data(bytes))
}

TexParameteri :: gl.TexParameteri
Uniform1f :: gl.Uniform1f

Uniform1fv :: proc(location: i32, v: []f32) {
	gl.Uniform1fv(location, i32(len(v)), raw_data(v))
}

Uniform1i :: gl.Uniform1i
Uniform2f :: gl.Uniform2f
Uniform3f :: gl.Uniform3f

Uniform3fv :: proc(location: i32, v: []glm.vec3) {
	gl.Uniform3fv(location, i32(len(v)), raw_data(mem.slice_data_cast([]f32, v)))
}

UniformMatrix4fv :: proc(location: i32, m: glm.mat4) {
	value := transmute([4 * 4]f32)m
	gl.UniformMatrix4fv(location, 1, false, &value[0])
}

UseProgram :: gl.UseProgram

VertexAttribPointer :: proc(index: i32, size: int, type: Enum, normalized: bool, stride: int, ptr: uintptr) {
	gl.VertexAttribPointer(u32(index), i32(size), type, normalized, i32(stride), ptr)
}

Viewport :: gl.Viewport

// Constants
ARRAY_BUFFER :: Enum(gl.ARRAY_BUFFER)
BLEND :: Enum(gl.BLEND)
CCW :: Enum(gl.CCW)
CLAMP_TO_EDGE :: Enum(gl.CLAMP_TO_EDGE)
COLOR_ATTACHMENT0 :: Enum(gl.COLOR_ATTACHMENT0)
COLOR_BUFFER_BIT :: Enum(gl.COLOR_BUFFER_BIT)
CULL_FACE :: Enum(gl.CULL_FACE)
DEPTH_ATTACHMENT :: Enum(gl.DEPTH_ATTACHMENT)
DEPTH_BUFFER_BIT :: Enum(gl.DEPTH_BUFFER_BIT)
DEPTH_COMPONENT24 :: Enum(gl.DEPTH_COMPONENT24)
DEPTH_TEST :: Enum(gl.DEPTH_TEST)
ELEMENT_ARRAY_BUFFER :: Enum(gl.ELEMENT_ARRAY_BUFFER)
FLOAT :: Enum(gl.FLOAT)
FRAMEBUFFER :: Enum(gl.FRAMEBUFFER)
FRAMEBUFFER_COMPLETE :: Enum(gl.FRAMEBUFFER_COMPLETE)
HALF_FLOAT :: Enum(gl.HALF_FLOAT)
LEQUAL :: Enum(gl.LEQUAL)
LINEAR :: Enum(gl.LINEAR)
LINEAR_MIPMAP_LINEAR :: Enum(gl.LINEAR_MIPMAP_LINEAR)
NEAREST :: Enum(gl.NEAREST)
ONE :: Enum(gl.ONE)
RENDERBUFFER :: Enum(gl.RENDERBUFFER)
REPEAT :: Enum(gl.REPEAT)
RGBA :: Enum(gl.RGBA)
RGBA16F :: Enum(gl.RGBA16F)
RGBA8 :: Enum(gl.RGBA8)
SRGB8_ALPHA8 :: Enum(gl.SRGB8_ALPHA8)
STATIC_DRAW :: Enum(gl.STATIC_DRAW)
TEXTURE0 :: Enum(gl.TEXTURE0)
TEXTURE1 :: Enum(gl.TEXTURE1)
TEXTURE_2D :: Enum(gl.TEXTURE_2D)
TEXTURE_MAG_FILTER :: Enum(gl.TEXTURE_MAG_FILTER)
TEXTURE_MIN_FILTER :: Enum(gl.TEXTURE_MIN_FILTER)
TEXTURE_WRAP_S :: Enum(gl.TEXTURE_WRAP_S)
TEXTURE_WRAP_T :: Enum(gl.TEXTURE_WRAP_T)
TRIANGLES :: Enum(gl.TRIANGLES)
// The WebGL value; PixelStorei keeps it for TexImage2DSlice.
UNPACK_FLIP_Y_WEBGL :: Enum(0x9240)
UNSIGNED_BYTE :: Enum(gl.UNSIGNED_BYTE)
UNSIGNED_INT :: Enum(gl.UNSIGNED_INT)

@(private = "file")
WEB_VERSION_LINE :: "#version 300 es"
@(private = "file")
DESKTOP_VERSION_LINE :: "#version 330 core"

// Set by PixelStorei(UNPACK_FLIP_Y_WEBGL, ...), read by TexImage2DSlice.
@(private = "file")
flip_y: bool

// The source with a leading "#version 300 es" line replaced by "#version 330 core", the rest unchanged.
shader_source_for_desktop :: proc(source: string, allocator := context.allocator) -> string {
	first_line, _, _ := strings.partition(source, "\n")
	if strings.trim_right(first_line, "\r") != WEB_VERSION_LINE {
		return strings.clone(source, allocator)
	}
	return strings.concatenate({DESKTOP_VERSION_LINE, source[len(WEB_VERSION_LINE):]}, allocator)
}

// A copy of the image bytes with the rows in reverse order.
@(private = "file")
rows_reversed :: proc(bytes: []byte, height: int, allocator := context.allocator) -> []byte {
	reversed := make([]byte, len(bytes), allocator)
	if height <= 0 {
		copy(reversed, bytes)
		return reversed
	}
	row_size := len(bytes) / height
	for row in 0 ..< height {
		source_start := (height - 1 - row) * row_size
		copy(reversed[row * row_size:], bytes[source_start:source_start + row_size])
	}
	return reversed
}
