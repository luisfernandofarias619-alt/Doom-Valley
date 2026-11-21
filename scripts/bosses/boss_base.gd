class_name BossBase
extends RefCounted
## Comportamento de um chefe. Cada chefe implementa a própria IA (d.ai no HTML), reação a fases e acertos
## e o próprio desenho. O motor comum (BossEncounter.boss_ai) cuida de tempo, invulnerabilidade, fases,
## descida de entrada e contato.

var g


func _init(game) -> void:
	g = game


## IA do chefe a cada quadro (depois da entrada).
func ai(_b: Enemy, _dt: float, _ph: int) -> void:
	pass


func on_phase(_b: Enemy, _ph: int) -> void:
	pass


## Retorne um número para substituir o dano do tiro (ex.: 1e-6 para anular) ou null para seguir o padrão.
func on_hit(_b: Enemy, _p: Projectile, _d: float):
	return null


func on_dead(_b: Enemy) -> void:
	pass


func draw(_c: CanvasItem, _b: Enemy) -> void:
	pass


## Camada com filtro linear (folhas de sprite pintadas).
func draw_sprites(_c: CanvasItem, _b: Enemy) -> void:
	pass


func draw_add(_c: CanvasItem, _b: Enemy) -> void:
	pass


func draw_top(_c: CanvasItem, _b: Enemy) -> void:
	pass


func draw_ground(_c: CanvasItem, _b: Enemy) -> void:
	pass


func update_always(_dt: float) -> void:
	pass


# ---------- utilidades comuns aos chefes (bsh, ring, aim, bmv, aA do HTML) ----------
func ang_to_player(b) -> float:
	return atan2(g.player.y - b.y, g.player.x - b.x)


func dist_to_player(b) -> float:
	return Vector2(g.player.x - b.x, g.player.y - b.y).length()


func ring(b, n: int, sp: float, col: Color, off: float, dmg: float) -> void:
	for i in n:
		g.boss_shot(b.x, b.y, off + i * TAU / n, sp, col, dmg)


func aim(b, n: int, sp: float, sd: float, col: Color, dmg: float) -> void:
	var a := ang_to_player(b)
	for i in n:
		g.boss_shot(b.x, b.y, a + (i - (n - 1) / 2.0) * sd, sp, col, dmg)


## Move o chefe em direção ao alvo com suavização, sem sair da área (bmv).
func bmv(b, dt: float, tx: float, ty: float, k: float) -> void:
	var W: Rect2 = g.world_rect()
	b.x += (clampf(tx, W.position.x + 60.0, W.end.x - 60.0) - b.x) * minf(1.0, dt * k)
	b.y += (clampf(ty, W.position.y + 60.0, W.end.y - 60.0) - b.y) * minf(1.0, dt * k)


func bolt(x: float, y: float, a: float, sp: float, col: Color, dmg: float, r: float = 5.0, o: Dictionary = {}) -> Projectile:
	var p: Projectile = g.boss_shot(x, y, a, sp, col, dmg, r)
	for k in o.keys():
		p.set(k, o[k])
	return p


func box() -> Rect2:
	return g.arena.box() if g.arena.on() else g.world_rect()


func hz(o: Dictionary) -> Dictionary:
	return g.hazards.add(o)
