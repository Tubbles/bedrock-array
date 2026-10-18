#version 300 es
precision highp float;
uniform mediump sampler2D source;
// One texel along the blur axis (step is a built-in GLSL function).
uniform vec2 texel_step;
in vec2 uv;
out vec4 colour;

const float weights[5] = float[5](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

// Nine tap Gaussian along one axis; two passes make it separable.
void main() {
	vec3 sum = texture(source, uv).rgb * weights[0];
	for (int index = 1; index < 5; index++) {
		vec2 offset = texel_step * float(index);
		sum += texture(source, uv + offset).rgb * weights[index];
		sum += texture(source, uv - offset).rgb * weights[index];
	}
	colour = vec4(sum, 1.0);
}
