shader_type canvas_item;
// Q8: low-HP vignette -- a magenta radial edge glow. `intensity` is driven from the HP ratio
// (hud.gd: 1 - smoothstep(0.1, 0.35, ratio)), `pulse` kicks on the primary beat, `flash` is the
// 0.15 s hit flash on player_damaged. All three stay 0 with Reduce Flashes on.

uniform vec4 tint : source_color = vec4(1.0, 0.0, 0.667, 0.55);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float inner_radius = 0.7;
uniform float outer_radius = 1.45;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(inner_radius, outer_radius, length(p));
	float strength = clamp(intensity * (0.7 + 0.3 * pulse) + flash, 0.0, 1.0);
	COLOR = vec4(tint.rgb, tint.a * edge * strength);
}
