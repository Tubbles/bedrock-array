# 0011: Physically based shading

Status: landed (2026-10-18, a28998d)

Goal: the forward program shades with the material's roughness and metallic through a GGX specular lobe and a Lambert diffuse term, the emissive added, so copper reads as metal and painted steel as paint under the one sun. The constant ambient and the gamma output stay until the sky ambient and HDR items. Builds on 0010.

Verify:
- `./build.sh check` validates the shaders, `./build.sh web light` builds; on the page copper shows a copper tinted highlight and painted steel a white one, concrete none (the user).

## Specification (main agent, 2026-10-18)

- `src/engine/shaders/forward.vert`: also outputs `world_position` (`vec3`, `(model * vec4(position, 1.0)).xyz`).
- `src/engine/shaders/forward.frag`: new uniforms `camera_position` (`vec3`), `roughness`, `metallic` (`float`), `emissive` (`vec3`); `in vec3 world_position`. In `main`, with `n = normalize(world_normal)`, `v = normalize(camera_position - world_position)`, `l = -sun_direction`, `h = normalize(l + v)`, `n_dot_l = max(dot(n, l), 0.0)`, `n_dot_v = max(dot(n, v), 0.0)`: `r = max(roughness, 0.045)` (GGX degenerates at zero), `alpha = r * r`; `D = alpha² / (π ((n·h)² (alpha² - 1) + 1)²)`; Smith with Schlick-GGX, `k = (r + 1)² / 8`, `G1(x) = x / (x (1 - k) + k)`, `G = G1(n_dot_l) G1(n_dot_v)`; Schlick Fresnel `F = F0 + (1 - F0) (1 - max(dot(h, v), 0))⁵` with `F0 = mix(vec3(0.04), albedo, metallic)`; `specular = D G F / (4 n_dot_l n_dot_v + 0.0001)`; `diffuse = (1 - F) (1 - metallic) albedo / π`. The sun's intensity is defined so that a white Lambert surface facing it returns the intensity: `radiance = sun_colour * π`. `linear = (diffuse + specular) * radiance * n_dot_l + ambient * albedo + emissive`, then the gamma output as before. Small named functions for D, G1 and F above `main`; `const float PI = 3.14159265;`.
- `src/engine/render_webgl.odin`: `Webgl_Uniforms` gains `camera_position, roughness, metallic, emissive`, fetched in `webgl_renderer_init`; `webgl_renderer_draw` sets `camera_position` from `list.camera.position` once per draw and per item the material's `roughness`, `metallic` and `emissive`.
- `doc/render.md`, The WebGL2 renderer: the shading sentence replaced: GGX, Smith-Schlick, Schlick Fresnel, Lambert, the roughness floor, the sun unit convention; the constant ambient and the gamma output still owed to stage 1.

Verify: `./build.sh check` (validation passes), `./build.sh test` (sixteen tests), `./build.sh web light`.
