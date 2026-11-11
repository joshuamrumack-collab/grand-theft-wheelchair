// "RETRO 2001" post-process: an early-2000s console look.
// Point-samples the frame at a low line count (PS2-ish 448i), quantises colour with a
// 4x4 ordered dither, pushes saturation, and adds a soft vignette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float lines = 420.0;        // vertical resolution to emulate
uniform float levels = 28.0;        // colour steps per channel
uniform float saturation = 1.22;
uniform float contrast = 1.06;
uniform float vignette = 0.28;
uniform float dither = 1.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec2 ss = 1.0 / SCREEN_PIXEL_SIZE;
	float px = ss.y / lines;                    // screen pixels per emulated pixel
	vec2 cells = floor(ss / px);
	vec2 cell = floor(SCREEN_UV * cells);
	vec2 uv = (cell + 0.5) / cells;
	vec3 c = texture(screen_tex, uv).rgb;
	// a touch of horizontal blur, like a composite cable
	c = mix(c, texture(screen_tex, uv + vec2(1.0 / cells.x, 0.0)).rgb, 0.22);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += bayer4(cell) * dither / levels;
	c = floor(c * levels + 0.5) / levels;
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - dot(v, v) * vignette * 1.6;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
