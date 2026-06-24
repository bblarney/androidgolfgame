shader_type spatial;
// Procedural golf-ball skin: two colours combined by a pattern selector, with a faint
// self-emission (matched to the surface) so the ball reads clearly against the turf -- the
// same trick the club heads use. Patterns are driven by the sphere's UVs so they wrap cleanly.

render_mode specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 color2 : source_color = vec3(0.2, 0.2, 0.2);
// 0 = solid, 1 = stripe, 2 = spots, 3 = two_tone
uniform int pattern = 0;

void fragment() {
	vec3 col = color;
	if (pattern == 1) {
		// Latitude bands wrapping around the ball.
		float s = step(0.5, fract(UV.y * 8.0));
		col = mix(color, color2, s);
	} else if (pattern == 2) {
		// Repeating dot grid.
		vec2 g = fract(UV * vec2(10.0, 6.0)) - 0.5;
		float spot = 1.0 - step(0.26, length(g));
		col = mix(color, color2, spot);
	} else if (pattern == 3) {
		// Split hemispheres.
		float t = step(0.5, UV.x);
		col = mix(color, color2, t);
	}
	ALBEDO = col;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
	EMISSION = col * 0.12;
}
