class_name ArenaCatedral
extends RefCounted
## Catedral Carmesim (arena do Drácula): piso de mármore escuro, tapete, luz dos vitrais e rosácea,
## bancos, pilares, caixões (quebram; na Lua de Sangue soltam morcegos) e velas (luz na escuridão).

var g
var ar


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(A: Dictionary) -> void:
	A.t = 44.0
	var px := 2
	var aw := ceili(A.w / px)
	var ah := ceili(A.h / px)
	var img := PixelArt.make(aw, ah)
	var t := int(A.t / 2)
	var rn := PixelArt.Lcg.new(41)
	for y in range(0, ah, 12):
		for x in range(0, aw, 12):
			var h := Fenda.fh(x / 12, y / 12, 5)
			img.fill_rect(Rect2i(x, y, 12, 12), Color("#1a1216") if h < 0.33 else (Color("#1e1519") if h < 0.66 else Color("#22181d")))
			img.fill_rect(Rect2i(x, y + 11, 12, 1), Color("#120c0f"))
			img.fill_rect(Rect2i(x + 11, y, 1, 12), Color("#120c0f"))
			img.fill_rect(Rect2i(x, y, 11, 1), Color("#2c2026"))
	var cx := aw >> 1
	img.fill_rect(Rect2i(cx - 40, t, 80, ah - 2 * t), Color("#4a0e1c"))   # tapete
	img.fill_rect(Rect2i(cx - 36, t, 72, ah - 2 * t), Color("#6a1428"))
	for y in range(t, ah - t, 16):
		PixelArt.fill(img, cx - 36, y, 72, 1, Color(1, 0.82, 0.24, 0.2))
	PixelArt.fill(img, cx - 40, t, 2, ah - 2 * t, Color(0.78, 0.63, 0.2, 0.33))
	PixelArt.fill(img, cx + 38, t, 2, ah - 2 * t, Color(0.78, 0.63, 0.2, 0.33))
	for i in 5:   # luz dos vitrais
		var x := t + 30 + rn.next() * (aw - 2 * t - 60)
		var y := t + 60 + rn.next() * (ah - 2 * t - 120)
		var r := 26.0 + rn.next() * 30.0
		for k in 3:
			PixelArt.fill_ellipse(img, x, y, r * (1.0 - k * 0.25), r * 0.7 * (1.0 - k * 0.25), Color(1, 0.16, 0.31, 0.07))
	var dark := Color("#0a0608")
	img.fill_rect(Rect2i(0, 0, aw, t), dark)
	img.fill_rect(Rect2i(0, ah - t, aw, t), dark)
	img.fill_rect(Rect2i(0, 0, t, ah), dark)
	img.fill_rect(Rect2i(aw - t, 0, t, ah), dark)
	for x in range(t, aw - t, 24):
		img.fill_rect(Rect2i(x, t - 10, 22, 10), Color("#2a1e24"))
		img.fill_rect(Rect2i(x, t - 10, 22, 2), Color("#3a2a32"))
	A.img = img
	A.tex = ImageTexture.create_from_image(img)
	A.px = px
	A.aw = aw
	A.ah = ah
	A.painted = true


func obstacles(A: Dictionary) -> Array:
	var W: float = A.w
	var H: float = A.h
	var o: Array = []
	for side in [-1.0, 1.0]:
		for i in 5:
			o.append({"k": "banco", "x": W / 2.0 + side * 260.0, "y": H * 0.42 + i * 170.0, "hw": 110.0, "hh": 14.0, "solid": true})
	for q in [[0.2, 0.25], [0.8, 0.25], [0.2, 0.8], [0.8, 0.8]]:
		o.append({"k": "pilarc", "x": W * q[0], "y": H * q[1], "r": 34.0, "solid": true})
	for q in [[0.36, 0.14], [0.64, 0.14], [0.12, 0.55], [0.88, 0.55]]:
		o.append({"k": "caixao", "x": W * q[0], "y": H * q[1], "hw": 18.0, "hh": 34.0, "solid": true, "brk": true, "hp": 160.0, "mhp": 160.0, "onBreak": _coffin_break})
	for q in [[0.12, 0.3], [0.88, 0.3], [0.12, 0.72], [0.88, 0.72], [0.4, 0.06], [0.6, 0.06]]:
		o.append({"k": "vela", "x": W * q[0], "y": H * q[1], "r": 10.0, "solid": true, "lit": true})
	return o


func _coffin_break(o: Dictionary) -> void:
	g.sfx("crate")
	g.fx.burst(o.x, o.y, Color("#4a2a1a"), 20, 240.0)
	var b: Enemy = g.enc.boss
	if b != null and b.ai is BossDracula and b.ph >= 1:
		for i in 3:
			var e := Enemy.new(o.x + (randf() - 0.5) * 40.0, o.y + (randf() - 0.5) * 40.0, "fast")
			e.color = Color("#7a0b25")
			e.hp = 30.0
			e.max_hp = 30.0
			g.enemies.append(e)
		g.hud_msg("Morcegos saem do caixão", Color("#ff2b55"))
	elif randf() < 0.6:
		g.add_pickup(o.x, o.y, "hp")


func post(_dt: float, _A: Dictionary) -> void:
	pass


func draw_floor_tex(c: CanvasItem, A: Dictionary) -> void:
	var px: int = A.px
	c.draw_texture_rect(A.tex, Rect2(0, 0, A.aw * px, A.ah * px), false)
	# rosácea (vetorial, por cima do piso)
	var cx: float = A.w / 2.0
	var cy: float = A.t + 16.0
	Draw.sector(c, Vector2(cx, cy), 92.0, PI, TAU, Color("#1a0a10"))
	for k in 8:
		var a := PI + k * PI / 8.0
		c.draw_line(Vector2(cx, cy), Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 88.0, Color(1, 0.17, 0.33, 0.53) if k % 2 else Color(1, 0.82, 0.24, 0.4), 4.0, true)
	var B: Rect2 = ar.box()
	var sh := [0.4, 0.28, 0.16, 0.08]
	for i in 4:
		var col := Color(0, 0, 0, sh[i])
		c.draw_rect(Rect2(B.position.x, B.position.y + i * 2, B.size.x, 2), col)
		c.draw_rect(Rect2(B.position.x + i * 2, B.position.y, 2, B.size.y), col)
		c.draw_rect(Rect2(B.end.x - 2 - i * 2, B.position.y, 2, B.size.y), col)


func draw_floor(_c: CanvasItem, _A: Dictionary) -> void:
	pass


func draw_objects(c: CanvasItem, A: Dictionary) -> void:
	for o in A.obj:
		if o.get("dead", false):
			continue
		match o.k:
			"banco":
				c.draw_rect(Rect2(o.x - o.hw + 4, o.y - o.hh + 6, o.hw * 2, o.hh * 2), Color(0, 0, 0, 0.4))
				c.draw_rect(Rect2(o.x - o.hw, o.y - o.hh - 8, o.hw * 2, o.hh * 2 + 8), Color("#3a2216"))
				c.draw_rect(Rect2(o.x - o.hw, o.y - o.hh - 8, o.hw * 2, 3), Color("#5a3424"))
				var x: float = -o.hw + 10.0
				while x < o.hw:
					c.draw_rect(Rect2(o.x + x, o.y - o.hh - 8, 3, o.hh * 2 + 8), Color("#2a160e"))
					x += 36.0
			"pilarc":
				Draw.ellipse(c, Vector2(o.x + 6, o.y + 8), o.r * 1.1, o.r * 0.8, Color(0, 0, 0, 0.45))
				Draw.circle(c, Vector2(o.x, o.y), o.r, Color("#2e2228"))
				Draw.circle(c, Vector2(o.x - 6, o.y - 6), o.r * 0.7, Color("#43323a"))
				Draw.ring(c, Vector2(o.x, o.y), o.r - 3.0, Color(1, 0.17, 0.33, 0.27), 2.0)
			"caixao":
				c.draw_rect(Rect2(o.x - o.hw + 5, o.y - o.hh + 6, o.hw * 2, o.hh * 2), Color(0, 0, 0, 0.45))
				var col := Color.WHITE if o.get("fl", 0.0) > 0.0 else Color("#2a1610")
				Draw.poly(c, PackedVector2Array([Vector2(o.x - o.hw * 0.7, o.y - o.hh), Vector2(o.x + o.hw * 0.7, o.y - o.hh), Vector2(o.x + o.hw, o.y - o.hh * 0.4),
					Vector2(o.x + o.hw * 0.6, o.y + o.hh), Vector2(o.x - o.hw * 0.6, o.y + o.hh), Vector2(o.x - o.hw, o.y - o.hh * 0.4)]), col)
				c.draw_rect(Rect2(o.x - 1, o.y - o.hh * 0.6, 2, o.hh * 0.9), Color("#c8a032"))
				c.draw_rect(Rect2(o.x - o.hw * 0.4, o.y - o.hh * 0.25, o.hw * 0.8, 2), Color("#c8a032"))
				if o.hp < o.mhp * 0.5:
					c.draw_rect(Rect2(o.x - 4, o.y - o.hh, 8, 3), Color(1, 0.17, 0.33, 0.6))
			"vela":
				c.draw_rect(Rect2(o.x - 2, o.y - 30, 4, 32), Color("#2a2218"))
				c.draw_rect(Rect2(o.x - 10, o.y - 30, 20, 3), Color("#2a2218"))
				for dx in [-8.0, 0.0, 8.0]:
					c.draw_rect(Rect2(o.x + dx - 1.5, o.y - 40, 3, 10), Color("#e8dcc0"))
					if o.lit:
						# BUG CORRIGIDO: o HTML usava o relógio do Jardim (GL.t) e as velas não tremulavam aqui
						var f := sin(A.tm * 14.0 + dx) * 1.2
						c.draw_rect(Rect2(o.x + dx - 1.5, o.y - 46 + f, 3, 5), Color("#ffb36b"))
						c.draw_rect(Rect2(o.x + dx - 0.5, o.y - 44 + f, 1, 2), Color("#fff3c0"))
		if o.get("fl", 0.0) > 0.0 and o.k != "caixao":
			if o.has("hw"):
				c.draw_rect(Rect2(o.x - o.hw, o.y - o.hh, o.hw * 2.0, o.hh * 2.0), Color(1, 1, 1, 0.6))
			else:
				Draw.circle(c, Vector2(o.x, o.y), o.r, Color(1, 1, 1, 0.6))


## Luzes da escuridão da Lua de Sangue: jogador, velas acesas, rosácea e o chefe quando prepara um golpe.
func lights(A: Dictionary) -> Array:
	var L: Array = [Vector3(g.player.x, g.player.y, 260.0)]
	for o in A.obj:
		if o.k == "vela" and o.lit and not o.get("dead", false):
			L.append(Vector3(o.x, o.y - 30.0, 190.0))
	L.append(Vector3(A.w / 2.0, A.t + 20.0, 220.0))
	var b: Enemy = g.enc.boss
	if b != null and b.chg > 0.0:
		L.append(Vector3(b.x, b.y, 120.0))
	return L
