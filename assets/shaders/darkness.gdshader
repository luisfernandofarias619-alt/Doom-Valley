shader_type canvas_item;
// Escuridão da Lua de Sangue (catDark do HTML): camada escura com "furos" de luz.
// Cada luz apaga a escuridão com um gradiente radial (opaco até 30% do raio, some no raio),
// equivalente ao 'destination-out' do canvas: escuridão final = força × Π(1 − luz_i).

uniform float strength = 0.0;
uniform int count = 0;
uniform vec3 lights[12];
uniform vec4 tint : source_color = vec4(0.008, 0.0, 0.016, 1.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float a = strength;
	for (int i = 0; i < 12; i++) {
		if (i >= count) {
			break;
		}
		float r = lights[i].z;
		float d = distance(lp, lights[i].xy);
		float k = clamp((r - d) / (0.7 * r), 0.0, 1.0);
		a *= (1.0 - k);
	}
	COLOR = vec4(tint.rgb, a);
}
