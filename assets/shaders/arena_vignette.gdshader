shader_type canvas_item;
// Vinheta com dither ordenado do piso da Contenção (arFloor do HTML), calculada por pixel da arte.
// Só o anel externo escurece; as paredes (faixa de largura `wall`) ficam de fora, como no original,
// onde a vinheta era aplicada ao piso antes de as paredes serem desenhadas por cima.

uniform vec2 art_size = vec2(720.0, 880.0);
uniform float wall = 22.0;
uniform bool enabled = false;

const float B[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const float M[5] = float[](1.0, 0.86, 0.73, 0.6, 0.48);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (enabled) {
		vec2 p = floor(UV * art_size);
		if (p.x >= wall && p.y >= wall && p.x < art_size.x - wall && p.y < art_size.y - wall) {
			vec2 ctr = floor(art_size * 0.5);
			float mxd = length(ctr);
			float r0 = 0.55 * mxd;
			float d = length(p - ctr);
			if (d > r0) {
				float v = min(1.0, (d - r0) / (0.5 * mxd));
				int bi = int(mod(p.y, 4.0)) * 4 + int(mod(p.x, 4.0));
				int l = min(4, int(floor(v * 4.0 + B[bi] / 16.0 * 0.999)));
				c.rgb *= M[l];
			}
		}
	}
	COLOR = c * COLOR;
}
