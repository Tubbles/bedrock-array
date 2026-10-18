#version 300 es
precision highp float;
const float PI = 3.14159265;
const int MAX_POINT_LIGHTS = 8;
uniform vec3 sun_direction;
uniform vec3 sun_colour;
uniform vec3 sky_colour;
uniform vec3 ground_colour;
uniform vec3 albedo;
uniform vec3 camera_position;
uniform float roughness;
uniform float metallic;
uniform vec3 emissive;
uniform int point_light_count;
uniform vec3 point_light_position[MAX_POINT_LIGHTS];
// Colour times intensity.
uniform vec3 point_light_colour[MAX_POINT_LIGHTS];
uniform float point_light_range[MAX_POINT_LIGHTS];
uniform int has_textures;
uniform sampler2D albedo_map;
uniform sampler2D normal_map;
uniform sampler2D surface_map;
// The world size one texture repeat covers at the near scale.
uniform float texture_metres;
// The primitive's half extents in its local space.
uniform vec3 half_extents;
// The wear rule of doc/workflows/materials.md.
uniform float wear_edge_width;
uniform float wear_chip_threshold;
uniform float wear_amount;
uniform vec3 wear_metal;
in vec3 world_normal;
in vec3 world_position;
in vec3 local_position;
out vec4 colour;

struct Surface {
	vec3 albedo;
	float roughness;
	float metallic;
};

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

// The light one direction l with the given radiance reflects towards v.
vec3 shade(Surface surface, vec3 n, vec3 v, vec3 l, vec3 radiance) {
	vec3 h = normalize(l + v);
	float n_dot_l = max(dot(n, l), 0.0);
	float n_dot_v = max(dot(n, v), 0.0);
	float n_dot_h = max(dot(n, h), 0.0);
	float h_dot_v = max(dot(h, v), 0.0);
	float r = max(surface.roughness, 0.045);
	float alpha = r * r;
	float k = (r + 1.0) * (r + 1.0) / 8.0;
	float d = distribution_ggx(n_dot_h, alpha);
	float g = geometry_schlick(n_dot_l, k) * geometry_schlick(n_dot_v, k);
	vec3 f = fresnel_schlick(h_dot_v, mix(vec3(0.04), surface.albedo, surface.metallic));
	vec3 specular = d * g * f / (4.0 * n_dot_l * n_dot_v + 0.0001);
	vec3 diffuse = (1.0 - f) * (1.0 - surface.metallic) * surface.albedo / PI;
	return (diffuse + specular) * radiance * n_dot_l;
}

// The weights of the three axis projections, sharpened towards the dominant axis, summing to 1.
vec3 triplanar_blend(vec3 n) {
	vec3 blend = pow(abs(n), vec3(4.0));
	return blend / (blend.x + blend.y + blend.z);
}

// The map projected along the three axes and weighted by the blend.
vec4 triplanar_colour(sampler2D map, vec3 p, vec3 blend) {
	return texture(map, p.zy) * blend.x + texture(map, p.xz) * blend.y + texture(map, p.xy) * blend.z;
}

// The near scale mixed with a far scale e times larger on rotated axes, so the period never shows.
vec4 triplanar_two_scales(sampler2D map, vec3 p, vec3 blend) {
	return mix(triplanar_colour(map, p, blend), triplanar_colour(map, p.zxy / 2.71828, blend.zxy), 0.5);
}

// The tangent space normal map in world space by the whiteout blend, near scale only.
vec3 triplanar_normal(sampler2D map, vec3 p, vec3 n, vec3 blend) {
	vec3 tx = texture(map, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(map, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(map, p.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * blend.x + ty.xzy * blend.y + tz.xyz * blend.z);
}

// The distance to the box's nearest edge: on a face, the second smallest of the three face distances.
float edge_distance() {
	vec3 d = half_extents - abs(local_position);
	return max(max(min(d.x, d.y), min(d.x, d.z)), min(d.y, d.z));
}

// 1 where the paint is chipped to the bare metal: where the wear field raised towards the edges exceeds the threshold.
float wear_at(float field) {
	float edge_raise = wear_amount * (1.0 - smoothstep(0.0, wear_edge_width, edge_distance()));
	return 1.0 - step(field + edge_raise, wear_chip_threshold);
}

// The material at this fragment: the uniforms, or the texture set tinted by the albedo uniform and chipped by the wear rule.
Surface surface_at(vec3 p, vec3 blend) {
	if (has_textures == 0) {
		return Surface(albedo, roughness, metallic);
	}
	vec4 surface = triplanar_two_scales(surface_map, p, blend);
	float wear = wear_at(surface.b);
	vec3 textured_albedo = mix(albedo * triplanar_two_scales(albedo_map, p, blend).rgb, wear_metal, wear);
	float textured_roughness = mix(surface.r, surface.g, wear);
	return Surface(textured_albedo, textured_roughness, mix(metallic, 1.0, wear));
}

void main() {
	vec3 geometric_normal = normalize(world_normal);
	vec3 p = world_position / texture_metres;
	vec3 blend = triplanar_blend(geometric_normal);
	Surface surface = surface_at(p, blend);
	vec3 n = geometric_normal;
	if (has_textures != 0) {
		n = triplanar_normal(normal_map, p, geometric_normal, blend);
	}
	vec3 v = normalize(camera_position - world_position);
	// sun_direction is the direction the light travels.
	vec3 linear = shade(surface, n, v, -sun_direction, sun_colour * PI);
	for (int index = 0; index < MAX_POINT_LIGHTS && index < point_light_count; index++) {
		vec3 to_light = point_light_position[index] - world_position;
		float light_distance = max(length(to_light), 0.0001);
		vec3 l = to_light / light_distance;
		float window = clamp(1.0 - pow(light_distance / point_light_range[index], 4.0), 0.0, 1.0);
		float attenuation = window * window / max(light_distance * light_distance, 0.01);
		linear += shade(surface, n, v, l, point_light_colour[index] * PI * attenuation);
	}
	linear += mix(ground_colour, sky_colour, n.y * 0.5 + 0.5) * surface.albedo + emissive;
	colour = vec4(linear, 1.0);
}
