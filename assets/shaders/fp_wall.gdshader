shader_type spatial;
render_mode unshaded, cull_disabled;
// Paredes da Anomalia em primeira pessoa (equivale ao laço DDA do raycaster do HTML):
// textura 32×32 sem filtragem, faces "y" do mapa 28% mais escuras, névoa até o preto em 10 unidades
// e paredes de carne (tipo 2) que respiram.

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform bool breathe = false;
uniform float tint = 1.0;

void fragment() {
	// posição e normal no mundo a partir do espaço de visão (vale também para as instâncias do MultiMesh)
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnrm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 c = texture(tex, UV);
	float side = abs(wnrm.z) > 0.5 ? 0.72 : 1.0;
	float fog = min(1.0, length(wpos.xz - CAMERA_POSITION_WORLD.xz) / 10.0);
	float br = 1.0;
	if (breathe) {
		br = 0.8 + 0.2 * sin(TIME * 3.0 + floor(wpos.x) + floor(wpos.z));
	}
	ALBEDO = c.rgb * (1.0 - fog) * side * br * tint;
}
