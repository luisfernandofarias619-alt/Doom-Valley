shader_type spatial;
render_mode unshaded, cull_disabled;
// Chão e teto da Anomalia: cor com névoa por distância (9 unidades), grade do chão, a faixa vermelha da
// investida "Fenda" e o ruído das paredes apagadas.

uniform bool is_ceiling = false;
uniform bool erase = false;
uniform bool fenda_on = false;
uniform vec4 fenda_seg = vec4(0.0);
uniform float time_s = 0.0;

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	float l = max(dot(d, d), 1e-6);
	float t = clamp(dot(p - a, d) / l, 0.0, 1.0);
	return length(p - a - d * t);
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wpos.xz;
	float rowd = length(p - CAMERA_POSITION_WORLD.xz);
	float k = 1.0 - min(1.0, rowd / 9.0);
	vec3 c;
	if (is_ceiling) {
		if (erase) {
			float s = mod(floor(wpos.z * 37.0) + floor(time_s * 20.0), 97.0);
			c = s < 1.0 ? vec3(1.0) : vec3(10.0, 4.0, 8.0) / 255.0;
		} else {
			c = vec3(12.0 * k + 4.0, 6.0 * k + 2.0, 24.0 * k + 4.0) / 255.0;
		}
	} else {
		vec3 base = vec3(16.0, 10.0, 30.0);
		if (erase) {
			float s = mod(floor(p.x * 3.0) * 73.0 + floor(p.y * 3.0) * 151.0, 97.0);
			base = s < 1.0 ? vec3(200.0) : vec3(4.0);
		} else {
			vec2 f = fract(p);
			if (f.x < 0.04 || f.y < 0.04) {
				base = vec3(40.0, 24.0, 70.0);
			}
			if (fenda_on && seg_d(p, fenda_seg.xy, fenda_seg.zw) < 0.45) {
				base = vec3(255.0, 40.0, 90.0);
			}
		}
		c = base * k / 255.0;
	}
	ALBEDO = c;
}
