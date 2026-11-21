extends Node2D
## Camada de desenho: delega o _draw() a uma função do jogo (equivale às passagens do draw() do HTML).

static var profile := {}   # nome da camada -> microssegundos acumulados (só com --bench)
static var profiling := false

var painter: Callable


func _draw() -> void:
	if not painter.is_valid():
		return
	if profiling:
		var t0 := Time.get_ticks_usec()
		painter.call(self)
		profile[name] = int(profile.get(name, 0)) + Time.get_ticks_usec() - t0
	else:
		painter.call(self)
