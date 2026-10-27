// shader: holo_gate
// type: spatial
// perf: low
// used_by: levels/slice/vertical_slice.tscn (ShaderMaterial_hologram: Z1/Z4/Z5 holo gates,
//          Z6 plaza walls, Zone 10 near rail)
//
// P2: a faint shimmering barrier instead of the old opaque cobalt slab (albedo a 0.3 +
// emission x2.5). Additive, so it only ever adds light: base alpha 0.12 everywhere, a fresnel
// rim on grazing faces, brighter bands in the top/bottom `edge_band` metres and a slow
// scanline drifting up. Unshaded outputs ALBEDO only (EMISSION is dropped), so the HDR
// tint rides on ALBEDO * intensity. cull_disabled draws every face of the 1 m slab (up to
// four layers at grazing angles), hence the low per-layer weights.
//
// `half_height` is an instance uniform: set `instance_shader_parameters/half_height` on a
// node whose box is not 12 m tall (the edge bands are measured from the box's local centre).

shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 rim_color : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.5;
uniform float edge_band = 0.3;
uniform float scan_lines_per_metre = 1.5;
uniform float scan_speed = 0.8;
uniform float fresnel_weight = 0.15;
uniform float scan_weight = 0.08;
uniform float intensity = 0.5;
instance uniform float half_height = 6.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), fresnel_power);
	float to_edge = half_height - abs(local_pos.y);
	float edge = 1.0 - smoothstep(0.0, edge_band, to_edge);
	float scan = pow(0.5 + 0.5 * sin((local_pos.y - TIME * scan_speed) * scan_lines_per_metre * 6.2831853), 12.0);
	float a = base_alpha + fresnel * fresnel_weight + scan * scan_weight;
	a = mix(a, edge_alpha, edge);
	ALBEDO = rim_color.rgb * intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
