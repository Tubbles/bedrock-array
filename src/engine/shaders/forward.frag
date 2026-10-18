#version 300 es
precision highp float;
const float PI = 3.14159265;
uniform vec3 sun_direction;
uniform vec3 sun_colour;
uniform float ambient;
uniform vec3 albedo;
uniform vec3 camera_position;
uniform float roughness;
uniform float metallic;
uniform vec3 emissive;
in vec3 world_normal;
in vec3 world_position;
out vec4 colour;

// GGX normal distribution.
float distribution_ggx(float n_dot_h, float alpha) {
	float alpha_squared = alpha * alpha;
	float denominator = n_dot_h * n_dot_h * (alpha_squared - 1.0) + 1.0;
	return alpha_squared / (PI * denominator * denominator);
}

// Schlick-GGX geometry term for one direction.
float geometry_schlick(float n_dot_x, float k) {
	return n_dot_x / (n_dot_x * (1.0 - k) + k);
}

// Schlick Fresnel.
vec3 fresnel_schlick(float h_dot_v, vec3 f0) {
	return f0 + (1.0 - f0) * pow(1.0 - h_dot_v, 5.0);
}

void main() {
	// sun_direction is the direction the light travels.
	vec3 n = normalize(world_normal);
	vec3 v = normalize(camera_position - world_position);
	vec3 l = -sun_direction;
	vec3 h = normalize(l + v);
	float n_dot_l = max(dot(n, l), 0.0);
	float n_dot_v = max(dot(n, v), 0.0);
	float n_dot_h = max(dot(n, h), 0.0);
	float h_dot_v = max(dot(h, v), 0.0);
	float r = max(roughness, 0.045);
	float alpha = r * r;
	float k = (r + 1.0) * (r + 1.0) / 8.0;
	float d = distribution_ggx(n_dot_h, alpha);
	float g = geometry_schlick(n_dot_l, k) * geometry_schlick(n_dot_v, k);
	vec3 f = fresnel_schlick(h_dot_v, mix(vec3(0.04), albedo, metallic));
	vec3 specular = d * g * f / (4.0 * n_dot_l * n_dot_v + 0.0001);
	vec3 diffuse = (1.0 - f) * (1.0 - metallic) * albedo / PI;
	vec3 radiance = sun_colour * PI;
	vec3 linear = (diffuse + specular) * radiance * n_dot_l + ambient * albedo + emissive;
	colour = vec4(pow(linear, vec3(1.0 / 2.2)), 1.0);
}
