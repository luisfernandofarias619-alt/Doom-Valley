class_name ArenaTemplo
extends RefCounted
## Templo do Olho (arena do Illuminatti): mármore, emblema central, olho na parede, colunas (cobertura),
## pirâmides de ouro (quebram e ferem o chefe), braseiros verdes, urnas com orbes, olhos do piso (enigma)
## e espinhos na fase 2.

var g
var ar


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(A: Dictionary) -> void:
	A.t = 56.0
	A.eyes = []
	for q in [[0.3, 0.4], [0.7, 0.4], [0.3, 0.76], [0.7, 0.76]]:
		A.eyes.append({"x": A.w * q[0], "y": A.h * q[1], "open": false, "cl": false, "cd": 0.0})
	A.spk = []
	A.glow = 0.0
	A.spT = 4.0
	A.puz = false
	A.painted = true


func obstacles(A: Dictionary) -> Array:
	var W: float = A.w
	var H: float = A.h
	var o: Array = []
	for q in [[0.18, 0.28], [0.82, 0.28], [0.18, 0.84], [0.82, 0.84]]:
		o.append({"k": "coluna", "x": W * q[0], "y": H * q[1], "r": 26.0, "solid": true, "sp": "coluna", "s": 1.1})
	for q in [[0.34, 0.2], [0.66, 0.2], [0.5, 0.92]]:
		o.append({"k": "piramide", "x": W * q[0], "y": H * q[1], "r": 34.0, "solid": true, "brk": true, "hp": 300.0, "mhp": 300.0, "sp": "piramide", "s": 0.6, "onBreak": _pyr_break})
	for q in [[0.1, 0.5], [0.9, 0.5], [0.1, 0.14], [0.9, 0.14]]:
		o.append({"k": "braseiro", "x": W * q[0], "y": H * q[1], "r": 16.0, "solid": true, "sp": "braseiro", "s": 0.8})
	for q in [[0.12, 0.66], [0.88, 0.66], [0.4, 0.9], [0.6, 0.9]]:
		o.append({"k": "urna", "x": W * q[0], "y": H * q[1], "r": 14.0, "solid": true, "brk": true, "hp": 30.0, "mhp": 30.0, "sp": "urna" if randf() < 0.5 else "urna2", "s": 0.7, "onBreak": _urn_break})
	return o


func _pyr_break(o: Dictionary) -> void:
	g.sfx("boom")
	g.shake(6.0)
	g.fx.burst(o.x, o.y, Color("#ffd23d"), 30, 300.0, 4.0)
	g.hud_msg("Uma pirâmide de ouro caiu", Color("#ffd23d"))
	var b: Enemy = g.enc.boss
	if b != null and b.ai is BossIlluminati:
		g.dmg_e(b, b.max_hp * 0.03, {})
		b.flash = 0.3


func _urn_break(o: Dictionary) -> void:
	g.sfx("crate")
	g.fx.burst(o.x, o.y, Color("#c070ff"), 14, 200.0)
	g.add_pickup(o.x, o.y, "hp" if randf() < 0.5 else "xp")


func post(dt: float, A: Dictionary) -> void:
	if A.glow > 0.0:
		A.glow = maxf(0.0, A.glow - dt)


func draw_floor_tex(c: CanvasItem, A: Dictionary) -> void:
	var v: Rect2 = ar.view_rect()
	var aw: float = A.w
	var ah: float = A.h
	var t: float = A.t
	c.draw_rect(Rect2(0, 0, aw, ah), Color("#0d0a12"))
	var tex: Texture2D = Assets.sheets.get("tmp")
	var T: Dictionary = Assets.atl.get("tmp", {})
	if tex:
		var fs := 64.0
		var M := [T.marmore[0], T.marmore2[0]]
		var y := t
		while y < ah - t:
			var x := t
			while x < aw - t:
				if x + fs > v.position.x and x < v.end.x and y + fs > v.position.y and y < v.end.y:
					var f: Array = M[int(Fenda.fh(int(x / fs), int(y / fs), 6) * 2.0)]
					c.draw_texture_rect_region(tex, Rect2(x, y, fs, fs), Rect2(f[0], f[1], f[2], f[3]))
				x += fs
			y += fs
		var e: Array = T.emblema[0]
		var ew := 560.0
		var eh := float(e[3]) / float(e[2]) * ew
		c.draw_texture_rect_region(tex, Rect2(aw / 2.0 - ew / 2.0, ah * 0.55 - eh / 2.0, ew, eh), Rect2(e[0], e[1], e[2], e[3]))
		var w: Array = T.parede[0]
		var wr := Rect2(w[0], w[1], w[2], w[3])
		var x := 0.0
		while x < aw:
			c.draw_texture_rect_region(tex, Rect2(x, 0, 64, t), wr)
			c.draw_texture_rect_region(tex, Rect2(x, ah - t, 64, t), wr)
			x += 64.0
		y = t
		while y < ah:
			c.draw_texture_rect_region(tex, Rect2(0, y, t, 64), wr)
			c.draw_texture_rect_region(tex, Rect2(aw - t, y, t, 64), wr)
			y += 64.0
		var o: Array = T.olho_parede[0]
		var ow := 300.0
		var oh := float(o[3]) / float(o[2]) * ow
		c.draw_texture_rect_region(tex, Rect2(aw / 2.0 - ow / 2.0, t - oh * 0.55, ow, oh), Rect2(o[0], o[1], o[2], o[3]))
	else:
		var y := t
		while y < ah - t:
			var x := t
			while x < aw - t:
				c.draw_rect(Rect2(x, y, 40, 40), Color("#15101c") if int(x / 40 + y / 40) % 2 else Color("#1a1422"))
				x += 40.0
			y += 40.0
		Draw.poly_stroke(c, PackedVector2Array([Vector2(aw / 2, ah * 0.4), Vector2(aw / 2 + 170, ah * 0.68), Vector2(aw / 2 - 170, ah * 0.68)]), Color(1, 0.82, 0.24, 0.4), 3.0)
	var sh := [0.5, 0.32, 0.18]
	for i in 3:
		var col := Color(0, 0, 0, sh[i])
		c.draw_rect(Rect2(t, t + i * 2, aw - 2 * t, 2), col)
		c.draw_rect(Rect2(t + i * 2, t, 2, ah - 2 * t), col)
		c.draw_rect(Rect2(aw - t - 2 - i * 2, t, 2, ah - 2 * t), col)


func draw_floor(_c: CanvasItem, _A: Dictionary) -> void:
	pass


func draw_objects(c: CanvasItem, A: Dictionary) -> void:
	var tm: float = g.game_time
	for e in A.eyes:
		var k := 0.6 + 0.4 * sin(tm * 6.0) if e.open else 0.35
		if not Assets.draw_atl(c, "tmp", "olho_piso" if e.open else "olho_verde", 0, e.x, e.y + 32.0, 0.9, 1.0, 0.25 if e.cl else k):
			Draw.circle(c, Vector2(e.x, e.y), 22.0, Color(1, 0.82, 0.24, k) if e.open else Color(0.24, 1, 0.48, k))
		if e.open:
			Draw.ring(c, Vector2(e.x, e.y), 34.0 + sin(tm * 5.0) * 3.0, Color(1, 0.82, 0.24, 0.8), 2.0)
	for s in A.spk:
		if s.t < 1.0:
			Draw.dashed_rect(c, Rect2(s.x - 30, s.y - 30, 60, 60), 5.0, 4.0, 0.0, Color(0.75, 0.44, 1, 0.4 + 0.4 * sin(tm * 20.0)), 1.0)
		else:
			Assets.draw_atl(c, "tmp", "espinhos", 0, s.x, s.y + 30.0, 0.95, 1.0)
	for o in A.obj:
		if o.get("dead", false):
			continue
		var r: float = o.get("r", 10.0)
		if not Assets.draw_atl(c, "tmp", o.sp, 0, o.x, o.y + r * 0.7, o.get("s", 1.0), 1.0):
			Draw.circle(c, Vector2(o.x, o.y), r, Color("#5a5040"))
		if o.get("fl", 0.0) > 0.0:
			Draw.circle(c, Vector2(o.x, o.y), r, Color(1, 1, 1, 0.5))


## Brilho verde aditivo dos braseiros (acende quando o chefe ataca).
func draw_floor_add(c: CanvasItem, A: Dictionary) -> void:
	var gl: float = A.glow
	for o in A.obj:
		if o.k != "braseiro" or o.get("dead", false):
			continue
		var a := 0.25 + 0.15 * sin(g.game_time * 9.0 + o.x) + gl * 0.4
		Draw.radial(c, Vector2(o.x, o.y - 30.0), 70.0 + gl * 60.0, Color(0.24, 1, 0.48, clampf(a, 0.0, 1.0)), Color(0.24, 1, 0.48, 0.0))
