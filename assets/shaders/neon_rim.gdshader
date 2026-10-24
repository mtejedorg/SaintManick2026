// shader: neon_rim
// type: spatial
// perf: low
// used_by: neon_rim_material.tres, neon_rim_material_magenta.tres
//
// Fresnel-based neon rim glow applied as material_overlay on CharacterVisual meshes.
// Does not replace the base material — it is ADDED on top (blend_add) via EMISSION.
// NOTE: in Godot 4 `unshaded` outputs ALBEDO only and drops EMISSION, so the old unshaded
// blend_mix overlay painted black over every silhouette edge. This version is lit-but-black
// (ALBEDO = 0, no specular) and emits the rim, which blend_add then sums onto the mesh.
//
// === Driven from GDScript ===
// CharacterVisual.update_rim_color(color)  — live rim color swap (telegraph flash)
// material.set_shader_parameter("rim_color", Color(...))  — direct override
// material.set_shader_parameter("rim_strength", 0.0)  — disable rim (e.g. dead state)

shader_type spatial;
// blend_add + depth_draw_never: the overlay only ever ADDS light (flat areas add 0) and never
// writes depth, so it can't z-fight with the base mesh beneath it.
render_mode blend_add, depth_draw_never, cull_back, specular_disabled;

// Legacy slot (kept so existing .tres parameter sets still load); ALBEDO is forced to black.
uniform vec4 albedo : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// --- Rim ---
uniform vec4 rim_color : source_color = vec4(0.0, 0.96, 1.0, 1.0); // cyan default
uniform float rim_power : hint_range(0.5, 8.0) = 3.5;
uniform float rim_strength : hint_range(0.0, 4.0) = 2.5; // >1 drives HDR bloom

// --- Optional constant emission (e.g. always-on glow for boss meshes) ---
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	// Fresnel: strongest at silhouette edges where surface normal is ~perpendicular to view
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);

	vec3 rim = rim_color.rgb * fresnel * rim_strength;

	// Black albedo + no specular: the only light this overlay contributes is EMISSION.
	ALBEDO = vec3(0.0);
	EMISSION = rim + emission_color.rgb * emission_strength;
	// Fully opaque in blend_add terms: ALPHA scales the added color, and fresnel already
	// fades the rim to zero in flat areas.
	ALPHA = 1.0;
}
