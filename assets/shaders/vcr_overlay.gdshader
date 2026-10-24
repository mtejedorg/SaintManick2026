// shader: vcr_overlay
// type: canvas_item (screen-space)
// perf: low
// used_by: ui/vcr/vcr_overlay.tscn
//
// Drone-feed VCR effect (GDD §6.2): a constant faint scanline overlay, plus
// chromatic-aberration/glitch bursts triggered on player damage and camera perspective
// shifts. Screen-space only — this is a canvas_item shader, not spatial, so there is no
// depth buffer to fight with. If a spatial variant is ever needed, use
// depth_draw_never (see assets/shaders/neon_rim.gdshader) to avoid z-fighting; a bad
// render_mode combination kills a shader silently in Godot 4.
//
// === Driven from GDScript ===
// VcrOverlay.trigger_burst(strength, duration) — spikes aberration_strength then decays it
// material.set_shader_parameter("scanline_strength", 0.0) — disable scanlines entirely

shader_type canvas_item;

// Godot 4.6 removed the built-in SCREEN_TEXTURE keyword in favor of an explicit
// hint_screen_texture uniform sampler — using the old keyword fails silently at
// shader-compile time (SHADER ERROR, caught by the headless smoke/import gate).
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

// --- Scanlines (always-on, subtle) ---
// The pattern is sin(uv.y * count): at 1080p a count of 1700 gives a ~4 px period (a fine CRT
// texture), where the old 540 gave 12.6 px bands that read as window blinds. Static by default
// (speed 0): a drifting grid shimmers at this density.
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.06;
uniform float scanline_count : hint_range(50.0, 2000.0) = 1700.0;
uniform float scanline_speed : hint_range(-2.0, 2.0) = 0.0;

// --- Chromatic aberration (spikes on damage / camera shift, GSScript drives this) ---
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.0;

// --- Vignette (constant, subtle — sells the "camera feed" read) ---
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration: sample R/G/B at slightly offset UVs, radiating from center.
	vec2 center_offset = uv - vec2(0.5);
	vec2 aberration_dir = center_offset * aberration_strength;

	float r = texture(screen_tex, uv - aberration_dir).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv + aberration_dir).b;
	vec3 color = vec3(r, g, b);

	// Scanlines: a faint horizontal band pattern that slowly drifts (a static grid would
	// read as a texture, not a live feed).
	float scan = sin((uv.y * scanline_count) + TIME * scanline_speed * 10.0);
	scan = (scan * 0.5 + 0.5); // 0..1, mean 0.5
	// 0.88 + 0.24 * scan swings 0.88..1.12 with a mean of exactly 1.0, so the overlay darkens
	// and brightens in equal measure instead of dimming the whole frame.
	color *= mix(1.0, 0.88 + 0.24 * scan, scanline_strength);

	// Vignette: darken the corners so the frame reads as a lens, not a flat overlay.
	float dist = length(center_offset);
	float vignette = 1.0 - smoothstep(0.4, 0.9, dist) * vignette_strength;
	color *= vignette;

	COLOR = vec4(color, 1.0);
}
