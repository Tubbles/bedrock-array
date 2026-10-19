#+build js wasm32
// The GL names the renderer draws through, so one renderer compiles for
// the browser and natively. This file maps them to WebGL2,
// api_native.odin to desktop OpenGL.
package glapi

import webgl "vendor:wasm/WebGL"

// Types
Enum :: webgl.Enum
Buffer :: webgl.Buffer
Texture :: webgl.Texture
Program :: webgl.Program
Framebuffer :: webgl.Framebuffer
Renderbuffer :: webgl.Renderbuffer
VertexArrayObject :: webgl.VertexArrayObject

// Procedures
ActiveTexture :: webgl.ActiveTexture
BindBuffer :: webgl.BindBuffer
BindFramebuffer :: webgl.BindFramebuffer
BindRenderbuffer :: webgl.BindRenderbuffer
BindTexture :: webgl.BindTexture
BindVertexArray :: webgl.BindVertexArray
BlendFunc :: webgl.BlendFunc
BufferDataSlice :: webgl.BufferDataSlice
CheckFramebufferStatus :: webgl.CheckFramebufferStatus
Clear :: webgl.Clear
ClearColor :: webgl.ClearColor
CreateBuffer :: webgl.CreateBuffer
CreateFramebuffer :: webgl.CreateFramebuffer
CreateProgramFromStrings :: webgl.CreateProgramFromStrings
CreateRenderbuffer :: webgl.CreateRenderbuffer
CreateTexture :: webgl.CreateTexture
CreateVertexArray :: webgl.CreateVertexArray
DeleteFramebuffer :: webgl.DeleteFramebuffer
DeleteRenderbuffer :: webgl.DeleteRenderbuffer
DeleteTexture :: webgl.DeleteTexture
DepthFunc :: webgl.DepthFunc
Disable :: webgl.Disable
DrawArrays :: webgl.DrawArrays
DrawElements :: webgl.DrawElements
Enable :: webgl.Enable
EnableVertexAttribArray :: webgl.EnableVertexAttribArray
FramebufferRenderbuffer :: webgl.FramebufferRenderbuffer
FramebufferTexture2D :: webgl.FramebufferTexture2D
FrontFace :: webgl.FrontFace
GenerateMipmap :: webgl.GenerateMipmap
GetExtension :: webgl.GetExtension
GetUniformLocation :: webgl.GetUniformLocation
PixelStorei :: webgl.PixelStorei
RenderbufferStorage :: webgl.RenderbufferStorage
TexImage2D :: webgl.TexImage2D
TexImage2DSlice :: webgl.TexImage2DSlice
TexParameteri :: webgl.TexParameteri
Uniform1f :: webgl.Uniform1f
Uniform1fv :: webgl.Uniform1fv
Uniform1i :: webgl.Uniform1i
Uniform2f :: webgl.Uniform2f
Uniform3f :: webgl.Uniform3f
Uniform3fv :: webgl.Uniform3fv
UniformMatrix4fv :: webgl.UniformMatrix4fv
UseProgram :: webgl.UseProgram
VertexAttribPointer :: webgl.VertexAttribPointer
Viewport :: webgl.Viewport

// Constants
ARRAY_BUFFER :: webgl.ARRAY_BUFFER
BLEND :: webgl.BLEND
CCW :: webgl.CCW
CLAMP_TO_EDGE :: webgl.CLAMP_TO_EDGE
COLOR_ATTACHMENT0 :: webgl.COLOR_ATTACHMENT0
COLOR_BUFFER_BIT :: webgl.COLOR_BUFFER_BIT
CULL_FACE :: webgl.CULL_FACE
DEPTH_ATTACHMENT :: webgl.DEPTH_ATTACHMENT
DEPTH_BUFFER_BIT :: webgl.DEPTH_BUFFER_BIT
DEPTH_COMPONENT24 :: webgl.DEPTH_COMPONENT24
DEPTH_TEST :: webgl.DEPTH_TEST
ELEMENT_ARRAY_BUFFER :: webgl.ELEMENT_ARRAY_BUFFER
FLOAT :: webgl.FLOAT
FRAMEBUFFER :: webgl.FRAMEBUFFER
FRAMEBUFFER_COMPLETE :: webgl.FRAMEBUFFER_COMPLETE
HALF_FLOAT :: webgl.HALF_FLOAT
LEQUAL :: webgl.LEQUAL
LINEAR :: webgl.LINEAR
LINEAR_MIPMAP_LINEAR :: webgl.LINEAR_MIPMAP_LINEAR
NEAREST :: webgl.NEAREST
ONE :: webgl.ONE
RENDERBUFFER :: webgl.RENDERBUFFER
REPEAT :: webgl.REPEAT
RGBA :: webgl.RGBA
RGBA16F :: webgl.RGBA16F
RGBA8 :: webgl.RGBA8
SRGB8_ALPHA8 :: webgl.SRGB8_ALPHA8
STATIC_DRAW :: webgl.STATIC_DRAW
TEXTURE0 :: webgl.TEXTURE0
TEXTURE1 :: webgl.TEXTURE1
TEXTURE_2D :: webgl.TEXTURE_2D
TEXTURE_MAG_FILTER :: webgl.TEXTURE_MAG_FILTER
TEXTURE_MIN_FILTER :: webgl.TEXTURE_MIN_FILTER
TEXTURE_WRAP_S :: webgl.TEXTURE_WRAP_S
TEXTURE_WRAP_T :: webgl.TEXTURE_WRAP_T
TRIANGLES :: webgl.TRIANGLES
UNPACK_FLIP_Y_WEBGL :: webgl.UNPACK_FLIP_Y_WEBGL
UNSIGNED_BYTE :: webgl.UNSIGNED_BYTE
UNSIGNED_INT :: webgl.UNSIGNED_INT
