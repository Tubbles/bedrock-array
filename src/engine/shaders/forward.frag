#version 300 es
precision mediump float;
uniform vec3 sun_direction;
uniform vec3 sun_colour;
uniform float ambient;
uniform vec3 albedo;
in vec3 world_normal;
out vec4 colour;
void main() {
	// sun_direction is the direction the light travels.
	float diffuse = max(dot(normalize(world_normal), -sun_direction), 0.0);
	vec3 linear = albedo * (ambient + diffuse * sun_colour);
	colour = vec4(pow(linear, vec3(1.0 / 2.2)), 1.0);
}
