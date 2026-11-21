extends Node2D
## Camada de desenho: delega o _draw() a uma função do jogo (equivale às passagens do draw() do HTML).

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
