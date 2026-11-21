class_name ArenaRotunda
extends RefCounted
## Rotunda dos Manuscritos (arena do Vesperon): piso de ladrilhos da folha 'rot', estantes nas paredes,
## círculo de leitura, colunas e estátuas que cobrem e quebram, cinzas e páginas caindo e, na fase 2,
## o mármore racha e as fendas viram brasa.

const T := 64.0

var g
var ar
var _emb := {}


func _init(game, arena) -> void:
	g = game
	ar = arena


func build(A: Dictionary) -> void:
	A.t = T
	A.emb = []
	A.ash = []
	A.p2 = false
	A.embT = 0.0
	A.painted = true


func obstacles(A: Dictionary) -> Array:
	var W: float = A.w
	var H: float = A.h
	var o: Array = []
	var P := func(k: String, x: float, y: float, sp: String) -> Dictionary:
		return {"k": k, "x": W * x, "y": H * y, "r": 30.0 if k == "estatua" else 26.0, "solid": true, "brk": true, "hp": 260.0, "mhp": 260.0, "sp": sp, "s": 1.0, "onBreak": _break}
	o.append(P.call("coluna", 0.27, 0.27, "pilar"))
	o.append(P.call("coluna", 0.73, 0.27, "pilar_o"))
	o.append(P.call("coluna", 0.27, 0.73, "pilar_o"))
	o.append(P.call("coluna", 0.73, 0.73, "pilar"))
	o.append(P.call("estatua", 0.5, 0.16, "estatua"))
	o.append(P.call("estatua", 0.14, 0.5, "estatua2"))
	o.append(P.call("estatua", 0.86, 0.5, "estatua"))
	for q in [[0.12, 0.12], [0.88, 0.12], [0.12, 0.88], [0.88, 0.88]]:
		o.append({"k": "deco", "x": W * q[0], "y": H * q[1], "sp": "candelabro", "s": 0.9})
	o.append({"k": "deco", "x": W * 0.5, "y": H * 0.88, "sp": "mesa", "s": 1.0, "solid": true, "hw": 44.0, "hh": 18.0})
	o.append({"k": "deco", "x": W * 0.2, "y": H * 0.92, "sp": "braseiro", "s": 0.9})
	o.append({"k": "deco", "x": W * 0.8, "y": H * 0.92, "sp": "runas", "s": 0.8})
	return o


func _break(o: Dictionary) -> void:
	g.sfx("rhslam")
	g.shake(5.0)
	g.fx.burst(o.x, o.y, Color("#b0a89e"), 30, 280.0, 4.0)
	g.fx.burst(o.x, o.y, Color("#ff9a3d"), 8, 180.0)
	var A = ar.cur
	if A != null:
		A.obj.append({"k": "entulho_r", "x": o.x, "y": o.y, "r": 24.0, "solid": true, "v": randi() % 3})
	g.hud_msg("A cobertura se despedaçou", Color("#b0a89e"))


## Fase 2: o mármore racha e as fendas viram brasa (área que queima depois de 1,2 s).
func post(dt: float, A: Dictionary) -> void:
	var b: Enemy = g.enc.boss
	if b == null or not (b.ai is BossVesperon) or g.enc.st != "active":
		return
	if A.p2:
		A.embT -= dt
		if A.embT <= 0.0 and A.emb.size() < 14:
			A.embT = 3.5
			var B: Rect2 = ar.box()
			var x := 0.0
			var y := 0.0
			var k := 0
			while true:
				x = B.position.x + 80.0 + randf() * (B.size.x - 160.0)
				y = B.position.y + 80.0 + randf() * (B.size.y - 160.0)
				k += 1
				if Vector2(x - g.player.x, y - g.player.y).length() >= 160.0 or k >= 20:
					break
			A.emb.append({"x": x, "y": y, "t": 0.0, "v": randi() % 4})
	for e in A.emb:
		e.t += dt
		if e.t > 1.2 and Vector2(g.player.x - e.x, g.player.y - e.y).length() < 36.0 and not g.player.is_dashing:
			g.take_damage(10.0 * dt, "area")


func draw_floor_tex(c: CanvasItem, A: Dictionary) -> void:
	var v: Rect2 = ar.view_rect()
	var aw: float = A.w
	var ah: float = A.h
	var t: float = A.t
	c.draw_rect(Rect2(0, 0, aw, ah), Color("#1a1614"))
	var tex: Texture2D = Assets.sheets.get("rot")
	var fs := 80.0
	if tex:
		var P: Array = Assets.atl.rot.piso
		var y := t
		while y < ah - t:
			var x := t
			while x < aw - t:
				if x + fs > v.position.x and x < v.end.x and y + fs > v.position.y and y < v.end.y:
					var f: Array = P[int(Fenda.fh(int(x / fs), int(y / fs), 4) * P.size())]
					c.draw_texture_rect_region(tex, Rect2(x, y, fs, fs), Rect2(f[0], f[1], f[2], f[3]))
				x += fs
			y += fs
		c.draw_rect(Rect2(t, t, aw - 2 * t, ah - 2 * t), Color(20 / 255.0, 14 / 255.0, 10 / 255.0, 0.35))
		var E: Array = Assets.atl.rot.estante
		var x := 0.0
		while x < aw:   # estantes: topo e fundo (girada 180°)
			var f: Array = E[int(x / 64.0) % E.size()]
			c.draw_texture_rect_region(tex, Rect2(x, 0, 64, t), Rect2(f[0], f[1], f[2], f[3]))
			c.draw_set_transform(Vector2(x + 64, ah), PI, Vector2.ONE)
			c.draw_texture_rect_region(tex, Rect2(0, 0, 64, t), Rect2(f[0], f[1], f[2], f[3]))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
			x += 64.0
		var y2 := t
		while y2 < ah - t:   # laterais
			var f: Array = E[int(y2 / 64.0) % E.size()]
			c.draw_set_transform(Vector2(t, y2), PI / 2.0, Vector2.ONE)
			c.draw_texture_rect_region(tex, Rect2(0, 0, 64, t), Rect2(f[0], f[1], f[2], f[3]))
			c.draw_set_transform(Vector2(aw - t, y2 + 64), -PI / 2.0, Vector2.ONE)
			c.draw_texture_rect_region(tex, Rect2(0, 0, 64, t), Rect2(f[0], f[1], f[2], f[3]))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
			y2 += 64.0
	else:
		var y := t
		while y < ah - t:
			var x := t
			while x < aw - t:
				c.draw_rect(Rect2(x, y, 40, 40), Color("#cfc8c0") if int(x / 40 + y / 40) % 2 else Color("#c4bcb2"))
				c.draw_rect(Rect2(x, y + 39, 40, 1), Color("#9a928a"))
				x += 40.0
			y += 40.0
		for r in [Rect2(0, 0, aw, t), Rect2(0, ah - t, aw, t), Rect2(0, 0, t, ah), Rect2(aw - t, 0, t, ah)]:
			c.draw_rect(r, Color("#2a1a10"))
	var cx := aw / 2.0
	var cy := ah / 2.0
	Draw.ring(c, Vector2(cx, cy), minf(aw, ah) * 0.32, Color(40 / 255.0, 20 / 255.0, 10 / 255.0, 0.5), 3.0)   # círculo de leitura
	Draw.ring(c, Vector2(cx, cy), minf(aw, ah) * 0.29, Color(40 / 255.0, 20 / 255.0, 10 / 255.0, 0.5), 1.0)
	var sh := [0.5, 0.32, 0.18]
	for i in 3:
		var col := Color(0, 0, 0, sh[i])
		c.draw_rect(Rect2(t, t + i * 2, aw - 2 * t, 2), col)
		c.draw_rect(Rect2(t + i * 2, t, 2, ah - 2 * t), col)
		c.draw_rect(Rect2(aw - t - 2 - i * 2, t, 2, ah - 2 * t), col)


func draw_floor(_c: CanvasItem, _A: Dictionary) -> void:
	pass


## Ladrilho em brasa (rotEmb): recorte da folha com borda suave, cacheado por variação.
func _ember_tex(v: int) -> Texture2D:
	if _emb.has(v):
		return _emb[v]
	var tex: Texture2D = Assets.sheets.get("rot")
	if tex == null:
		return null
	var L: Array = Assets.atl.rot.brasa
	var f: Array = L[v % L.size()]
	var src := tex.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var img := src.get_region(Rect2i(f[0], f[1], f[2], f[3]))
	img.resize(88, 88, Image.INTERPOLATE_BILINEAR)
	for y in 88:
		for x in 88:
			var d := Vector2(x - 44, y - 44).length()
			var m := 1.0 if d < 18.0 else (lerpf(1.0, 0.8, (d - 18.0) / (0.7 * 44.0 - 18.0)) if d < 0.7 * 44.0 else lerpf(0.8, 0.0, (d - 0.7 * 44.0) / (0.3 * 44.0)))
			var p := img.get_pixel(x, y)
			p.a *= clampf(m, 0.0, 1.0)
			img.set_pixel(x, y, p)
	var t := ImageTexture.create_from_image(img)
	_emb[v] = t
	return t


func draw_objects(c: CanvasItem, A: Dictionary) -> void:
	for e in A.emb:
		var k := minf(1.0, e.t / 1.2)
		var on: bool = e.t > 1.2
		var im := _ember_tex(e.v)
		if im:
			c.draw_texture_rect(im, Rect2(e.x - 44, e.y - 44, 88, 88), false, Color(1, 1, 1, k * (0.82 + 0.12 * sin(A.tm * 3.0 + e.x))))
		if not on:
			Draw.dashed_ring(c, Vector2(e.x, e.y), 36.0, 5.0, 6.0, -A.tm * 30.0, Color(1, 0.7, 0.42, 0.55 * k), 2.0)
	for o in A.obj:
		if o.get("dead", false):
			continue
		if o.k == "entulho_r":
			var cont = ar.themes.contencao
			cont._sprites()
			c.draw_texture_rect(cont.obs.entulho[int(o.v)], Rect2(o.x - 32, o.y - 32, 64, 64), false)
			continue
		var r: float = o.get("r", 0.0)
		if not Assets.draw_atl(c, "rot", o.sp, 0, o.x, o.y + (r * 0.6 if r > 0.0 else 10.0), o.get("s", 1.0), 1.0):
			Draw.circle(c, Vector2(o.x, o.y), r if r > 0.0 else 14.0, Color("#7a726a"))
		if o.get("fl", 0.0) > 0.0:
			Draw.circle(c, Vector2(o.x, o.y), r if r > 0.0 else 14.0, Color(1, 1, 1, 0.5))
		if o.get("brk", false) and o.hp < o.mhp * 0.5:
			c.draw_polyline(PackedVector2Array([Vector2(o.x - 8, o.y - 30), Vector2(o.x + 2, o.y - 14), Vector2(o.x - 4, o.y)]), Color.BLACK, 2.0, true)


## Brilho aditivo das brasas.
func draw_floor_add(c: CanvasItem, A: Dictionary) -> void:
	for e in A.emb:
		var k := minf(1.0, e.t / 1.2)
		var on: bool = e.t > 1.2
		var p := (0.32 if on else 0.14) + 0.1 * sin(A.tm * (7.0 if on else 3.0) + e.y)
		Draw.radial(c, Vector2(e.x, e.y), 46.0, Color(1, 0.54, 0.16, maxf(0.0, p * k)), Color(1, 0.24, 0, 0))


## Cinzas e páginas caindo (rotAsh).
func draw_after(c: CanvasItem, A: Dictionary) -> void:
	if not Settings.s.amb:
		return
	var v: Rect2 = ar.view_rect()
	var n := 60 if Settings.s.q >= 2 else 30
	while A.ash.size() < n:
		A.ash.append([v.position.x + randf() * v.size.x, v.position.y + randf() * v.size.y, 1 if randf() < 0.12 else 0, randf() * 9.0])
	var gt: float = g.game_time
	for a in A.ash:
		a[1] += (26.0 if a[2] else 40.0) * 0.016
		a[0] += sin(gt + a[3]) * 0.4
		if a[1] > v.end.y:
			a[1] = v.position.y
			a[0] = v.position.x + randf() * v.size.x
		if a[2]:
			c.draw_set_transform(Vector2(a[0], a[1]), sin(gt * 2.0 + a[3]), Vector2.ONE)
			c.draw_rect(Rect2(-4, -3, 8, 6), Color(0.85, 0.81, 0.75, 0.5))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			c.draw_rect(Rect2(a[0], a[1], 2, 2), Color(1, 0.6, 0.24, 0.4) if a[3] > 7.0 else Color(0.23, 0.2, 0.19, 0.4))
