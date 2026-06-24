shader_type spatial;
render_mode cull_disabled;

// Terrain detail shader. The mesh already carries a flat per-surface vertex COLOR
// (fairway / rough / green / sand ...). On its own that reads as plastic, so here we
// keep the vertex colour as the base albedo and break it up procedurally in world space:
//   * two octaves of value-noise mottle the brightness (lush/worn patches in the turf,
//     grain in the sand) so no surface is a single flat tone;
//   * the noise gradient perturbs the normal a touch, so raking light catches the
//     surface like real grass/sand instead of a smooth sheet.
// World-space sampling means the pattern is stable as the ball/camera move and tiles
// seamlessly across the whole hole.

uniform float macro_scale   = 0.11;   // broad lush/worn patches (cycles per world metre)
uniform float detail_scale  = 2.6;    // fine blade/grain frequency
uniform float detail_amount = 0.16;   // +/- albedo brightness variation
uniform float bump_amount   = 0.28;   // normal perturbation strength
uniform float roughness_val = 0.9;

// Sand (vertex-colour alpha ~0.5): a separate, matte look. Fine wind-blown grain plus a
// directional ripple, with the ripple lines also tilting the normal so low sun rakes
// across the raked surface and the bunker lip.
uniform float sand_grain_scale = 5.5;   // high-frequency grain
uniform float sand_ripple_freq = 0.9;   // raked-ripple spacing (cycles per world metre)
uniform float sand_ripple_amp  = 0.10;  // +/- albedo brightness from the ripples
uniform float sand_ripple_dir  = 0.6;   // ripple orientation (radians)
uniform float sand_bump_amount = 0.5;   // normal tilt strength along the ripples

varying vec3 v_world;
varying vec3 v_wnormal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	v_world   = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = v_world.xz;

	// Vertex-colour alpha buckets the surface: 0 = green (smooth), 0.5 = sand, 1 = turf.
	float a       = COLOR.a;
	bool  is_sand = a > 0.25 && a < 0.75;

	if (is_sand) {
		// Raked-sand ripples: a directional sine across the grain, plus fine value-noise so
		// the surface never reads as a clean wave. Matte (rough = 1) so it stays flat-lit.
		vec2 rdir   = vec2(cos(sand_ripple_dir), sin(sand_ripple_dir));
		float along = dot(p, rdir);
		float grain = fbm(p * sand_grain_scale);
		float phase = along * sand_ripple_freq * 6.2831853 + grain * 2.0;
		float tint  = 1.0 + sin(phase) * sand_ripple_amp + (grain - 0.5) * 2.0 * 0.06;
		ALBEDO    = COLOR.rgb * tint;
		ROUGHNESS = 1.0;

		// Tilt the normal along the ripple crests so raking light catches each band and the
		// bunker lip. Derivative of the ripple wrt the rake direction.
		float dr = cos(phase) * sand_ripple_freq;
		vec3  wn = normalize(v_wnormal + vec3(-rdir.x, 0.0, -rdir.y) * dr * sand_bump_amount);
		NORMAL   = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	} else {
		// Turf/green path. Alpha masks the detail off on the green (0 = smooth putting surface).
		float mask = a;

		// Brightness mottle: broad patches blended with fine detail, centred on 1.0.
		float macro = fbm(p * macro_scale);
		float n0    = fbm(p * detail_scale);
		float comb  = mix(macro, n0, 0.55);
		float tint  = 1.0 + (comb - 0.5) * 2.0 * detail_amount * mask;
		ALBEDO    = COLOR.rgb * tint;
		ROUGHNESS = roughness_val;

		// Fine bump: forward-difference the detail noise and tilt the world normal, then take
		// it back to view space (where Godot expects NORMAL in the fragment stage). Masked off
		// on the green so it keeps its flat geometric normal.
		float e  = 0.4;
		float hx = fbm((p + vec2(e, 0.0)) * detail_scale) - n0;
		float hz = fbm((p + vec2(0.0, e)) * detail_scale) - n0;
		vec3 wn  = normalize(v_wnormal + vec3(-hx, 0.0, -hz) * bump_amount * mask);
		NORMAL   = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}
