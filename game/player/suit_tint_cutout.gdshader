shader_type spatial;
render_mode cull_disabled;
// The cut-out version (an outfit with see-through windows, drawn from both sides).
// A suit material with the player's color: where the mask is white, the texture's brightness is
// kept and its hue becomes the tint (the camo keeps its pattern, stripes keep their shading).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear, repeat_enable;
uniform bool has_normal = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 tint : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform float gain = 1.6;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform float alpha_cut = 0.5;

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 c = a.rgb * base_color.rgb;
	ALPHA = a.a * base_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	float m = texture(mask_tex, UV).r;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * clamp(l * gain, 0.0, 1.25);
	ALBEDO = mix(c, t, m);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
