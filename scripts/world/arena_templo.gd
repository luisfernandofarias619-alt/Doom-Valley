class_name ArenaTemplo
extends RefCounted

var g
var ar


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(_A: Dictionary) -> void:
	pass


func obstacles(_A: Dictionary) -> Array:
	return []


func post(_dt: float, _A: Dictionary) -> void:
	pass


func draw_floor(c: CanvasItem, A: Dictionary) -> void:
	ar._draw_energy(c, A)
