#version 300 es
out vec2 uv;
// One triangle that covers the screen, no vertex attributes.
const vec2 positions[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
void main() {
	vec2 position = positions[gl_VertexID];
	uv = position * 0.5 + 0.5;
	gl_Position = vec4(position, 0.0, 1.0);
}
