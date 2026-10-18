#version 300 es
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
