// Directional wind sway for vegetation (grass tufts, tree canopies, scrub).
//
// The meshes are built "ground-rooted" (local origin at the base, +Y up), so a vertex's
// local Y doubles as a bend mask: the base stays planted and higher parts sway more.
// Each MultiMesh instance is phase-offset by its world position so neighbours don't sway
// in lockstep. Vertex colour carries the albedo (dark base -> light tip on grass).
//
// `wind_dir` is the world-space horizontal direction the wind blows TOWARD (matches the ball
// drift and the HUD arrow). Plants lean and gust along it. The direction is world-space, so we
// project it into each instance's local axes before bending VERTEX. Instances are yaw-rotated
// and uniformly scaled, so normalizing the basis columns recovers the pure rotation -- much
// cheaper than inverse(MODEL_MATRIX) and it makes every instance lean the same way in the world.
shader_type spatial;
render_mode cull_disabled;

uniform float wind_speed    : hint_range(0.0, 8.0) = 1.6;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.10;
uniform vec2  wind_dir = vec2(0.0, 1.0);

void vertex() {
	float mask = max(VERTEX.y, 0.0);
	vec3  org  = MODEL_MATRIX[3].xyz;          // instance world origin -> per-instance phase
	float t    = TIME * wind_speed + org.x * 0.6 + org.z * 0.45;
	// Always leaning downwind (0.65 bias) with a gust that pulses but never flips upwind.
	float gust = 0.65 + 0.35 * (sin(t) + 0.3 * sin(t * 2.3 + 1.7));
	float bend = gust * mask * wind_strength;
	// Resolve the world wind direction in this instance's local frame (yaw + uniform scale only).
	vec3 bx = normalize(MODEL_MATRIX[0].xyz);
	vec3 bz = normalize(MODEL_MATRIX[2].xyz);
	vec3 wd = vec3(wind_dir.x, 0.0, wind_dir.y);
	VERTEX.x += bend * dot(wd, bx);
	VERTEX.z += bend * dot(wd, bz);
}

void fragment() {
	ALBEDO    = COLOR.rgb;
	ROUGHNESS = 0.9;
}
