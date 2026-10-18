#version 300 es
precision highp float;
uniform mediump sampler2D source;
// One texel of the source texture.
uniform vec2 texel;
in vec2 uv;
out vec4 colour;

vec3 sample_at(vec2 offset) {
	return texture(source, uv + offset * texel).rgb;
}

// 3 by 3 tent, weights 1 2 1, 2 4 2, 1 2 1 over 16, one source texel apart.
void main() {
	vec3 sum = sample_at(vec2(-1.0, 1.0)) + sample_at(vec2(1.0, 1.0)) + sample_at(vec2(-1.0, -1.0)) + sample_at(vec2(1.0, -1.0));
	sum += 2.0 * (sample_at(vec2(0.0, 1.0)) + sample_at(vec2(-1.0, 0.0)) + sample_at(vec2(1.0, 0.0)) + sample_at(vec2(0.0, -1.0)));
	sum += 4.0 * sample_at(vec2(0.0, 0.0));
	colour = vec4(sum / 16.0, 1.0);
}
