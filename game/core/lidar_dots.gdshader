shader_type spatial;
// Lidar dots: small glowing points that face the camera and fade out over about 15 seconds.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float time_now = 0.0;
uniform float lifetime = 15.0;
uniform float dot_size = 0.025;

varying float fade;

void vertex() {
	// Billboard: build the quad in view space around the instance's position.
	vec4 center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float dist = max(-center.z, 0.1);
	float size = dot_size * (0.6 + dist * 0.04);
	vec4 view_pos = center + vec4(VERTEX.xy * size, 0.0, 0.0);
	POSITION = PROJECTION_MATRIX * view_pos;
	float age = time_now - INSTANCE_CUSTOM.x;
	fade = (age < 0.0 || age > lifetime) ? 0.0 : 1.0 - age / lifetime;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = dot(uv, uv);
	if (r > 1.0 || fade <= 0.0) {
		discard;
	}
	ALBEDO = COLOR.rgb * fade * (1.0 - r * 0.6);
}
