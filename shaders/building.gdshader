// Building facade: windows, sills, floor lines and randomly lit windows at night.
// Works in object space, so every building gets clean whole windows whatever its size.
shader_type spatial;

uniform vec4 wall_color : source_color = vec4(0.8, 0.7, 0.6, 1.0);
uniform float night = 0.0;
uniform float odd = 0.0;          // 0.5 when the building has an odd number of floors
uniform float window_w = 4.0;     // metres per window column
uniform float floor_h = 3.0;      // metres per floor
uniform float retro = 0.0;
uniform sampler2D facade_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_tex = 0.0;      // 1 = multiply in the painted brick / concrete texture        // 1 = crunchy low-res texel look

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 n = abs(ln);
	vec3 col = wall_color.rgb;
	float rough = 0.85;
	float metal = 0.0;
	vec3 em = vec3(0.0);
	if (n.y < 0.5) {
		vec2 uv = n.x > 0.5 ? vec2(lp.z, lp.y) : vec2(lp.x, lp.y);
		if (retro > 0.5) {
			uv = floor(uv * 5.0) / 5.0 + 0.1;
		}
		vec2 cell = vec2(uv.x / window_w, uv.y / floor_h + odd);
		vec2 f = fract(cell);
		vec2 id = floor(cell) + vec2(round(ln.x) * 17.0 + round(ln.z) * 31.0);
		// gentle large-scale grime
		col *= 0.93 + 0.07 * hash(floor(uv * 0.5));
		if (use_tex > 0.5) {
			vec3 ft = texture(facade_tex, uv * 0.25).rgb;
			col *= mix(vec3(1.0), ft * 1.15, 0.85);
		}
		if (retro > 0.5) {
			// chunky brick / stucco noise and a dirty skirt near the ground, PS2-texture style
			col *= 0.9 + 0.12 * hash(floor(uv * 5.0));
		}
		if (f.y < 0.05) {
			col *= 0.8;
		}
		bool win = f.x > 0.15 && f.x < 0.85 && f.y > 0.24 && f.y < 0.82;
		if (win) {
			float sky = smoothstep(0.24, 0.82, f.y);
			col = mix(vec3(0.10, 0.14, 0.20), vec3(0.32, 0.42, 0.55), sky * 0.6);
			col += vec3(0.18, 0.22, 0.28) * step(f.x, 0.32);
			rough = 0.06;
			metal = 0.5;
			float lit = step(0.42, hash(id));
			vec3 warm = mix(vec3(1.0, 0.75, 0.42), vec3(0.75, 0.85, 1.0), step(0.85, hash(id + 3.1)));
			em = warm * lit * night * 2.2;
			col = mix(col, warm * 0.6, lit * night * 0.6);
			if (abs(f.x - 0.5) < 0.014) {
				col = wall_color.rgb * 0.75;
				em = vec3(0.0);
				rough = 0.8;
				metal = 0.0;
			}
		} else if (f.y > 0.2 && f.y < 0.24 && f.x > 0.12 && f.x < 0.88) {
			col = wall_color.rgb * 0.68;
		} else if ((f.x > 0.13 && f.x < 0.15 || f.x > 0.85 && f.x < 0.87) && f.y > 0.24 && f.y < 0.82) {
			col = wall_color.rgb * 0.82;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal * (1.0 - retro);
	EMISSION = em;
}
