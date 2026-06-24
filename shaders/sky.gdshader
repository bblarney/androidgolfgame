shader_type sky;

// A hand-written sky: vertical gradient + a glowing sun disk + drifting procedural
// clouds. ProceduralSkyMaterial cannot draw clouds, which is why the old sky read as
// a flat blue-grey. All values are tuned for a bright, pleasant daytime golf sky.

uniform vec3  sky_top_color     : source_color = vec3(0.09, 0.32, 0.72); // zenith
uniform vec3  sky_horizon_color : source_color = vec3(0.66, 0.83, 0.95); // horizon haze
uniform float horizon_falloff   = 0.55;

uniform vec3  sun_direction      = vec3(0.40, 0.45, 0.80); // overwritten from code
uniform vec3  sun_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float sun_size           = 0.015;  // angular radius of the disk
uniform float sun_glow           = 220.0;  // tightness of the halo around the disk

uniform vec3  cloud_color  : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3  cloud_shadow : source_color = vec3(0.62, 0.68, 0.78);
uniform float cloud_coverage = 0.42;   // 0 = clear, 1 = overcast
uniform float cloud_sharpness = 0.10;  // edge softness of the cloud mask
uniform float cloud_scale     = 1.6;
uniform float cloud_speed     = 0.010;

// --- value-noise fbm ---------------------------------------------------------
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
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p = p * 2.02 + vec2(11.7, 5.3);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Vertical gradient. pow() pushes the haze band down toward the horizon.
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(sky_horizon_color, sky_top_color, pow(up, horizon_falloff));

	// Sun disk + soft halo.
	float sd = dot(dir, normalize(sun_direction));
	float disk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.4, sd);
	float halo = pow(max(sd, 0.0), sun_glow) * 0.6;
	col += sun_color * (disk + halo);

	// Clouds, only in the upper hemisphere. Project the view dir onto a flat "cloud
	// plane" overhead; fade them out as they approach the horizon so they never wrap
	// under the player.
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.18) * cloud_scale;
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.6);
		float n = fbm(uv);
		float mask = smoothstep(cloud_coverage, cloud_coverage + cloud_sharpness, n);
		// A second, finer fbm fakes lit tops vs. shaded undersides.
		float lit = fbm(uv * 2.3 + 7.0);
		vec3 cloud = mix(cloud_shadow, cloud_color, clamp(lit + 0.25, 0.0, 1.0));
		// Brighten clouds that sit near the sun.
		cloud += sun_color * halo * 0.5;
		float edge_fade = smoothstep(0.0, 0.22, dir.y);
		col = mix(col, cloud, mask * edge_fade * 0.92);
	}

	COLOR = col;
}
