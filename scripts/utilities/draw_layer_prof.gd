class_name DrawLayerProf
## Acesso ao perfilador das camadas de desenho (usado pelo teste de carga).

static func on() -> bool:
	return load("res://scripts/core/draw_layer.gd").profiling


static func add(k: String, us: int) -> void:
	var p: Dictionary = load("res://scripts/core/draw_layer.gd").profile
	p[k] = int(p.get(k, 0)) + us
