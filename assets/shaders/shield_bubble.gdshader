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
//
// U3: a blocked hit sends a ripple across the bubble. The boss (vfx/shield_bubble_fx.gd) sets
// hit_pos (world) and tweens hit_time 0 -> 1: a bright ring expands from hit_pos and fades out
// by hit_time 1.0 (the resting value, which draws nothing). Each boss owns its own copy of the
// material, so uniforms are never shared.
//
// V4: rim_color is set per boss in the scene (Enforcer magenta, Headliner amber); intensity 1.6 and
// fresnel_power 4.5 keep the bubble a thin outline instead of a pale solid ball.

shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 rim_color : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.5;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float intensity = 1.6;
uniform vec3 hit_pos = vec3(0.0);
uniform float hit_time = 1.0;
uniform float ripple_radius = 4.0;   // metres the ring travels by hit_time 1.0
uniform float ripple_width = 0.7;    // half-thickness of the ring (metres)
uniform float ripple_alpha = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float dist = distance(world_pos, hit_pos);
	float ring = 1.0 - smoothstep(0.0, ripple_width, abs(dist - hit_time * ripple_radius));
	float ripple = ring * (1.0 - hit_time) * ripple_alpha;
	ALBEDO = rim_color.rgb * intensity;
	ALPHA = clamp(fresnel * rim_alpha + ripple, 0.0, 1.0);
}
