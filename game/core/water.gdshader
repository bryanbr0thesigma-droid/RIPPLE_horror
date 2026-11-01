shader_type spatial;
// Clear pool water with ripple rings. Every noise in the water draws a ring that spreads out from
// where it happened, so players can see exactly what the creature hears.
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.32, 0.62, 0.68, 0.5);
// A soft glow from within (the mineral water), slowly shimmering. 0 = none.
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow = 0.0;
uniform float time_now = 0.0;
// xy = world x, z; z = start time; w = strength (0 = unused)
uniform vec4 ripples[16];

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float h = 0.0;
	vec2 grad = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		vec4 r = ripples[i];
		float age = time_now - r.z;
		if (r.w <= 0.0 || age < 0.0 || age > 6.0) {
			continue;
		}
		vec2 to_p = p - r.xy;
		float d = length(to_p);
		float radius = age * 1.4;
		float x = d - radius;
		float ring = exp(-x * x * 6.0);
		float fade = r.w * (1.0 - age / 6.0) / (1.0 + d * 0.25);
		h += sin(x * 14.0) * ring * fade;
		grad += (to_p / max(d, 0.001)) * cos(x * 14.0) * ring * fade * 14.0;
	}
	// A slow, gentle sway so the water never looks frozen.
	float sway_x = sin(p.x * 1.3 + time_now * 0.5) * 0.015 + sin(p.y * 2.1 - time_now * 0.4) * 0.01;
	float sway_z = cos(p.y * 1.1 + time_now * 0.45) * 0.015 + cos(p.x * 1.9 + time_now * 0.35) * 0.01;
	vec3 n = normalize(vec3(-grad.x * 0.05 + sway_x, 1.0, -grad.y * 0.05 + sway_z));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = water_color.rgb + vec3(h * 0.12);
	ALPHA = clamp(water_color.a + abs(h) * 0.1, 0.0, 1.0);
	float shimmer = 0.85 + 0.1 * sin(time_now * 0.7 + p.x * 0.9 + p.y * 0.6) + 0.05 * sin(time_now * 1.9 - p.x * 2.3);
	EMISSION = glow_color * glow * shimmer * (1.0 + h * 0.6);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
