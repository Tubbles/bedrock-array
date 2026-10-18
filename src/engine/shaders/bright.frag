#version 300 es
precision highp float;
uniform mediump sampler2D scene;
uniform float threshold;
in vec2 uv;
out vec4 colour;

// Keeps only the light above the threshold, the part that blooms.
void main() {
	colour = vec4(max(texture(scene, uv).rgb - threshold, 0.0), 1.0);
}
