#version 300 es
precision highp float;
uniform mediump sampler2D scene;
uniform mediump sampler2D bloom;
uniform float exposure;
uniform float bloom_strength;
// The chain accumulates every level into level 0, so a flat scene arrives bloom_levels times over.
uniform float bloom_levels;
in vec2 uv;
out vec4 colour;

// ACES filmic fit of Narkowicz 2015.
vec3 aces_fit(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void main() {
	vec3 scene_colour = mix(texture(scene, uv).rgb, texture(bloom, uv).rgb / bloom_levels, bloom_strength);
	vec3 linear = scene_colour * exposure;
	colour = vec4(pow(aces_fit(linear), vec3(1.0 / 2.2)), 1.0);
}
