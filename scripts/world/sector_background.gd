class_name SectorBackground
extends RefCounted
## Fundos animados dos 5 setores do campo aberto (ZN, zCore/zRings/zForge/zNet/zTunnel, rStars, rBG do HTML).
## Desenhados em coordenadas de tela; a troca de setor abre um círculo a partir do jogador.

const ZN := [
	{"n": "NÚCLEO", "c": "#00f2ff", "bg": "#06080e"},
	{"n": "VÓRTEX", "c": "#a06bff", "bg": "#0a0612"},
	{"n": "FORJA", "c": "#ff6a2b", "bg": "#120705"},
	{"n": "ABISMO", "c": "#19e6b8", "bg": "#031110"},
	{"n": "SINGULARIDADE", "c": "#ffd966", "bg": "#0e0c05"},
]

var g
var cur := 0
var prev := -1
var zt := 9.0
var stars: Array[Vector3] = []
var nxa := PackedFloat32Array()
var nya := PackedFloat32Array()


func _init(game) -> void:
	g = game
	nxa.resize(40)
	nya.resize(40)


func reset() -> void:
	cur = mini(ZN.size() - 1, g.sec)
	prev = -1
	zt = 9.0


func update(dt: float) -> void:
	zt += dt


func _check_zone() -> void:
	var z := mini(ZN.size() - 1, g.sec)
	if z != cur:
		prev = cur
		cur = z
		zt = 0.0
		g.banner("SETOR %d: %s" % [z + 1, ZN[z].n], Color(ZN[z].c), 2.4)
		g.shake(3.0)
		g.sfx("zone")


func draw(c: CanvasItem) -> void:
	_check_zone()
	g.intensity = minf(1.0, g.enemies.size() / 40.0)
	var vw: float = g.vw
	var vh: float = g.vh
	if zt < 1.3 and prev >= 0:
		_zdraw(c, prev, vw, vh)
		var k := 1.0 - pow(1.0 - zt / 1.3, 3.0)
		var R := k * Vector2(vw, vh).length()
		var q: Vector2 = g.world_to_screen(Vector2(g.player.x, g.player.y))
		# o setor novo aparece dentro de um círculo que cresce a partir do jogador
		var col := Color(ZN[cur].bg)
		Draw.circle(c, q, R, col)
		_zdraw_fx(c, cur, vw, vh, q, R)
		Draw.ring(c, q, R, Draw.alpha(Color(ZN[cur].c), 1.0 - k), 4.0)
	else:
		_zdraw(c, cur, vw, vh)


func _zdraw(c: CanvasItem, i: int, w: float, h: float) -> void:
	c.draw_rect(Rect2(0, 0, w, h), Color(ZN[i].bg))
	_zdraw_fx(c, i, w, h, Vector2.ZERO, -1.0)


## clip_r > 0: só desenha o que estiver dentro do círculo (transição entre setores).
func _zdraw_fx(c: CanvasItem, i: int, w: float, h: float, clip_c: Vector2, clip_r: float) -> void:
	var col := Color(ZN[i].c)
	var t: float = g.game_time
	var kp: float = g.kp
	var IN: float = g.intensity
	match i:
		0:   # NÚCLEO: estrelas e linhas de varredura
			_stars(c, w, h, clip_c, clip_r)
			for j in 3:
				var y := fmod(t * 60.0 + j * h / 3.0, h)
				if clip_r < 0.0 or absf(y - clip_c.y) < clip_r:
					var x0 := 0.0
					var x1 := w
					if clip_r > 0.0:
						var hw := sqrt(maxf(0.0, clip_r * clip_r - (y - clip_c.y) ** 2))
						x0 = maxf(0.0, clip_c.x - hw)
						x1 = minf(w, clip_c.x + hw)
					c.draw_line(Vector2(x0, y), Vector2(x1, y), Draw.alpha(col, 0.1 + 0.25 * kp), 1.0)
		1:   # VÓRTEX: anéis tracejados girando
			var ctr := Vector2(w / 2.0, h / 2.0)
			var m := Vector2(w, h).length() / 2.0
			for j in range(1, 7):
				var r := m * j / 6.0
				if clip_r > 0.0 and ctr.distance_to(clip_c) - r > clip_r:
					continue
				Draw.dashed_ring(c, ctr, r, 14.0, 18.0, (1.0 if j % 2 else -1.0) * t * 24.0, Draw.alpha(col, (0.07 + 0.13 * IN + 0.2 * kp) * (1.0 - j / 8.0)), 1.5)
			for j in 8:
				var a := t * 0.4 + j * 0.785
				var r := m * (0.25 + fmod(0.1 * j, 0.7))
				var p := ctr + Vector2(cos(a), sin(a)) * r
				if clip_r < 0.0 or p.distance_to(clip_c) < clip_r:
					c.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Draw.alpha(col, 0.4))
		2:   # FORJA: faíscas diagonais
			var n := 22 if Settings.s.q > 0 else 12
			var sp := 120.0 + 120.0 * IN
			for j in n:
				var k := float(j) / n
				var x := fmod(j * 97.0 + t * sp * (0.5 + k), w + 200.0) - 100.0
				var y := fmod(j * 53.0, h)
				if clip_r > 0.0 and Vector2(x, y).distance_to(clip_c) > clip_r + 100.0:
					continue
				c.draw_line(Vector2(x, y), Vector2(x - 90.0, y + 60.0), Draw.alpha(col, (0.05 + 0.12 * k + 0.2 * kp) * (0.5 + IN)), 2.0, true)
		3:   # ABISMO: rede de nós
			var n := 26 if Settings.s.q > 0 else 14
			for j in n:
				nxa[j] = (sin(t * 0.13 + j * 1.7) * 0.5 + 0.5) * w
				nya[j] = (cos(t * 0.11 + j * 2.3) * 0.5 + 0.5) * h
			for a in n:
				for b in range(a + 1, n):
					var d := Vector2(nxa[a] - nxa[b], nya[a] - nya[b]).length()
					if d < 130.0:
						var pa := Vector2(nxa[a], nya[a])
						if clip_r > 0.0 and pa.distance_to(clip_c) > clip_r:
							continue
						c.draw_line(pa, Vector2(nxa[b], nya[b]), Draw.alpha(col, (1.0 - d / 130.0) * (0.18 + 0.2 * kp + 0.15 * IN)), 1.0)
			for j in n:
				if clip_r < 0.0 or Vector2(nxa[j], nya[j]).distance_to(clip_c) < clip_r:
					c.draw_rect(Rect2(nxa[j] - 2.0, nya[j] - 2.0, 4, 4), Draw.alpha(col, 0.5))
		4:   # SINGULARIDADE: túnel hexagonal
			var ctr := Vector2(w / 2.0, h / 2.0)
			var m := Vector2(w, h).length() / 2.0
			for j in 7:
				var k := fmod(t * 0.18 + j / 7.0, 1.0)
				var r := m * k * 1.1
				if clip_r > 0.0 and r > clip_r + ctr.distance_to(clip_c):
					continue
				var pts := Draw.reg(6, r, t * 0.2, ctr)
				Draw.poly_stroke(c, pts, Draw.alpha(col, (1.0 - k) * (0.18 + 0.2 * IN + 0.25 * kp)), 1.5)


func _stars(c: CanvasItem, w: float, h: float, clip_c: Vector2, clip_r: float) -> void:
	if Settings.s.q == 0:
		return
	if stars.is_empty():
		for i in 70:
			stars.append(Vector3(randf() * w, randf() * h, 0.2 + randf() * 0.8))
	var n := 70 if Settings.s.q > 1 else 35
	var ox: float = g.player.x - w / 2.0
	var oy: float = g.player.y - h / 2.0
	var t: float = g.game_time
	for i in n:
		var s := stars[i]
		var x := fposmod(s.x - ox * s.z * 0.1, w)
		var y := fposmod(s.y - oy * s.z * 0.1, h)
		if clip_r > 0.0 and Vector2(x, y).distance_to(clip_c) > clip_r:
			continue
		c.draw_rect(Rect2(x, y, s.z * 2.0, s.z * 2.0), Color(0.62, 0.85, 1, 0.15 + 0.4 * s.z * (0.6 + 0.4 * sin(t * 2.0 + s.x))))
