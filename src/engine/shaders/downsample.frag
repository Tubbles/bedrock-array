#version 300 es
precision highp float;
uniform mediump sampler2D source;
// One texel of the source texture.
uniform vec2 texel;
// 1 on the first level: each box weighted by 1 / (1 + luma) so a single bright pixel does not flicker.
uniform int karis;
in vec2 uv;
out vec4 colour;

vec3 sample_at(vec2 offset) {
	return texture(source, uv + offset * texel).rgb;
}

float karis_weight(vec3 box) {
	return 1.0 / (1.0 + dot(box, vec3(0.2126, 0.7152, 0.0722)));
}

// The 13 tap downsample of Jimenez 2014: four overlapping boxes on a 2 texel ring and one inner box.
void main() {
	vec3 a = sample_at(vec2(-2.0, 2.0));
	vec3 b = sample_at(vec2(0.0, 2.0));
	vec3 c = sample_at(vec2(2.0, 2.0));
	vec3 d = sample_at(vec2(-2.0, 0.0));
	vec3 e = sample_at(vec2(0.0, 0.0));
	vec3 f = sample_at(vec2(2.0, 0.0));
	vec3 g = sample_at(vec2(-2.0, -2.0));
	vec3 h = sample_at(vec2(0.0, -2.0));
	vec3 i = sample_at(vec2(2.0, -2.0));
	vec3 j = sample_at(vec2(-1.0, 1.0));
	vec3 k = sample_at(vec2(1.0, 1.0));
	vec3 l = sample_at(vec2(-1.0, -1.0));
	vec3 m = sample_at(vec2(1.0, -1.0));
	vec3 box0 = (a + b + d + e) * 0.25;
	vec3 box1 = (b + c + e + f) * 0.25;
	vec3 box2 = (d + e + g + h) * 0.25;
	vec3 box3 = (e + f + h + i) * 0.25;
	vec3 box4 = (j + k + l + m) * 0.25;
	vec3 sum;
	if (karis == 1) {
		float weight0 = 0.125 * karis_weight(box0);
		float weight1 = 0.125 * karis_weight(box1);
		float weight2 = 0.125 * karis_weight(box2);
		float weight3 = 0.125 * karis_weight(box3);
		float weight4 = 0.5 * karis_weight(box4);
		sum = box0 * weight0 + box1 * weight1 + box2 * weight2 + box3 * weight3 + box4 * weight4;
		sum /= weight0 + weight1 + weight2 + weight3 + weight4;
	} else {
		sum = 0.125 * (box0 + box1 + box2 + box3) + 0.5 * box4;
	}
	colour = vec4(sum, 1.0);
}
