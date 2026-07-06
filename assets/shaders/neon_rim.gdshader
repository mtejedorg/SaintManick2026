// shader: neon_rim
// type: spatial
// perf: low
// used_by: neon_rim_material.tres, neon_rim_material_magenta.tres
//
// Fresnel-based neon rim glow applied as material_overlay on CharacterVisual meshes.
// Does not replace the base material — stacks additively via EMISSION.
//
// === Driven from GDScript ===
// CharacterVisual.update_rim_color(color)  — live rim color swap (telegraph flash)
// material.set_shader_parameter("rim_color", Color(...))  — direct override
// material.set_shader_parameter("rim_strength", 0.0)  — disable rim (e.g. dead state)

shader_type spatial;
// blend_mix + depth_draw_never: overlay is transparent in flat areas and never
// writes to the depth buffer, preventing z-fighting with the base mesh beneath it.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_disabled, unshaded;

// Base albedo — kept fully transparent so the underlying material shows through.
// Alpha is ignored by the blend mode on overlay; this slot exists for shader completeness.
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

	ALBEDO = albedo.rgb;
	EMISSION = rim + emission_color.rgb * emission_strength;
	// Keep the overlay transparent in non-rim regions so the base mesh albedo is unaffected.
	ALPHA = clamp(fresnel * rim_strength * 0.5, 0.0, 1.0);
}
