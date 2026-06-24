// Gentle flutter for the pin flag.
//
// The flag mesh is a subdivided PlaneMesh (lying in local XZ, normal +Y) anchored at the
// pole: local X = 0 sits against the pole and grows toward the free edge. X doubles as a
// flutter mask -- the attached edge stays put and the free edge ripples most. A travelling
// sine wave in TIME pushes the cloth along its normal (local Y) for a soft wind-blown wave,
// with a tiny tug along the height (local Z). TIME-driven, no _process.
shader_type spatial;
render_mode cull_disabled;

uniform vec3  flag_color    : source_color = vec3(0.82, 0.20, 0.18);
uniform float wind_speed    : hint_range(0.0, 12.0) = 4.0;
uniform float wave_amp      : hint_range(0.0, 1.0)  = 0.16;

void vertex() {
	float d = max(VERTEX.x, 0.0);              // distance from the pole edge
	float t = TIME * wind_speed;
	float wave = sin(d * 5.0 - t) + 0.35 * sin(d * 11.0 - t * 1.7);
	VERTEX.y += wave * wave_amp * d;           // out-of-plane flutter; free edge moves most
	VERTEX.z += 0.25 * sin(d * 4.0 - t * 0.9) * d * wave_amp;
}

void fragment() {
	ALBEDO    = flag_color;
	ROUGHNESS = 0.9;
}
