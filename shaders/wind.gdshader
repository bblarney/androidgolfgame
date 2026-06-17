// Gentle wind sway for vegetation (grass tufts, tree canopies, scrub).
//
// The meshes are built "ground-rooted" (local origin at the base, +Y up), so a vertex's
// local Y doubles as a bend mask: the base stays planted and higher parts sway more.
// Each MultiMesh instance is phase-offset by its world position so neighbours don't sway
// in lockstep. Vertex colour carries the albedo (dark base -> light tip on grass).
//
// Sway is applied in LOCAL space, so with the random per-instance yaw the wind direction
// varies per instance -- cheap and reads fine for a soft breeze (no matrix inverse).
shader_type spatial;
render_mode cull_disabled;

uniform float wind_speed    : hint_range(0.0, 8.0) = 1.6;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.10;

void vertex() {
	float mask = max(VERTEX.y, 0.0);
	vec3  org  = MODEL_MATRIX[3].xyz;          // instance world origin
	float t    = TIME * wind_speed + org.x * 0.6 + org.z * 0.45;
	float sx   = sin(t) + 0.4 * sin(t * 2.3 + 1.7);
	float sz   = cos(t * 0.8 + 1.1);
	VERTEX.x += sx * mask * wind_strength;
	VERTEX.z += sz * mask * wind_strength * 0.6;
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.9;
}
