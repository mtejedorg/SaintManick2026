// shader: shield_bubble
// type: spatial
// perf: low
// used_by: characters/enemies/enforcer/enforcer.tscn, characters/enemies/headliner/headliner.tscn
//          (next_pass of the ShieldBubble StandardMaterial3D)
//
// P2: the shield bubble is a faint additive fill (the StandardMaterial3D base: blend ADD,
// alpha 0.10) plus this fresnel rim in cyan-steel, so the bubble outline reads "shield up"
// while the boss inside stays readable. Kept as a next_pass so the Headliner's overheat tint
// (headliner_state_bullet_hell.gd) still drives the base material's albedo/emission.

shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 rim_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float intensity = 3.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	ALBEDO = rim_color.rgb * intensity;
	ALPHA = clamp(fresnel * rim_alpha, 0.0, 1.0);
}
