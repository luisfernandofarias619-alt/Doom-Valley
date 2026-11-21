class_name Fenda
extends RefCounted
## Fenda Infinita (FEN do HTML): arena sem limites gerada por pedaços de 320 px em 5 biomas, monólitos,
## âncoras que precisam ser sincronizadas e profundidade crescente.

const FCH := 320.0
const FPX := 2
const FAR := 160
const FBI := [
	{"n": "NÚCLEO", "c": "#00f2ff", "a": "#05090f", "b": "#08111a"},
	{"n": "VÓRTEX", "c": "#a06bff", "a": "#0a0614", "b": "#110b1f"},
	{"n": "FORJA", "c": "#ff6a2b", "a": "#120806", "b": "#1b0e09"},
	{"n": "ABISMO", "c": "#19e6b8", "a": "#031110", "b": "#061b18"},
	{"n": "SINGULARIDADE", "c": "#ffd966", "a": "#0e0c05", "b": "#17140a"},
]

var g
var ar
var on := false
var o := Vector2(100000, 100000)
var ch := {}
var mo := {}
var dep := 0
var anc := {}
var nt := 6.0
var t := 0.0
var maxd := 0.0
var sync := false
var bud := 2
var r0 := Vector2i.ZERO
var el0 = null
var best := 0


func _init(game, arena) -> void:
	g = game
	ar = arena


static func imul(a: int, b: int) -> int:
	return ((a & 0xffffffff) * (b & 0xffffffff)) & 0xffffffff


static func fh(x: int, y: int, s: int) -> float:
	var h := imul(x, 374761393) ^ imul(y, 668265263) ^ imul(s, 1442695041)
	h &= 0xffffffff
	h = imul(h ^ (h >> 13), 1274126177)
	return float((h ^ (h >> 16)) & 0xffffffff) / 4294967296.0


func reset() -> void:
	on = true
	dep = 0
	anc = {}
	nt = 5.0
	t = 0.0
	maxd = 0.0
	sync = false
	ch.clear()
	mo.clear()
	r0 = Vector2i(floori(floorf(o.x / FCH) / 3.0), floori(floorf(o.y / FCH) / 3.0))
	if el0 == null:
		el0 = g.cfg.elite


func leave() -> void:
	on = false
	if el0 != null:
		g.cfg.elite = el0
		el0 = null


func rate() -> float:
	return minf(0.07, 0.024 + 0.005 * dep + (0.02 if sync else 0.0))


func bio(cx: int, cy: int) -> int:
	var rx := floori(cx / 3.0)
	var ry := floori(cy / 3.0)
	if rx == r0.x and ry == r0.y:
		return 0
	return int(fh(rx, ry, 7) * 5.0)


func mono(cx: int, cy: int) -> Array:
	var k := Vector2i(cx, cy)
	if mo.has(k):
		return mo[k]
	var m: Array = []
	var n := (2 if fh(cx, cy, 12) < 0.25 else 1) if fh(cx, cy, 11) < 0.5 else 0
	var b := bio(cx, cy)
	for i in n:
		var x := cx * FCH + 56.0 + fh(cx, cy, 20 + i) * (FCH - 112.0)
		var y := cy * FCH + 56.0 + fh(cx, cy, 30 + i) * (FCH - 112.0)
		if Vector2(x - o.x, y - o.y).length() < 380.0:
			continue
		m.append({"k": "monolito", "x": x, "y": y, "r": 20.0 + fh(cx, cy, 40 + i) * 16.0, "solid": true, "b": b, "s": fh(cx, cy, 50 + i)})
	if mo.size() > 600:
		mo.clear()
	mo[k] = m
	return m


func near() -> Array:
	var v: Rect2 = ar.view_rect()
	var M := 420.0
	var out: Array = []
	for j in range(floori((v.position.y - M) / FCH), floori((v.end.y + M) / FCH) + 1):
		for i in range(floori((v.position.x - M) / FCH), floori((v.end.x + M) / FCH) + 1):
			out.append_array(mono(i, j))
	return out


func _chunk(cx: int, cy: int):
	var k := Vector2i(cx, cy)
	if ch.has(k):
		ch[k].u = t
		return ch[k]
	if bud <= 0:
		return null
	bud -= 1
	var b := bio(cx, cy)
	var B: Dictionary = FBI[b]
	var img := PixelArt.make(FAR, FAR)
	var rn := PixelArt.Lcg.new((imul(cx, 73856093) ^ imul(cy, 19349663)) & 0xffffffff)
	for ty in range(0, FAR, 16):
		for tx in range(0, FAR, 16):
			img.fill_rect(Rect2i(tx, ty, 16, 16), Color(B.a) if rn.next() < 0.5 else Color(B.b))
			PixelArt.fill(img, tx, ty, 16, 1, Color(1, 1, 1, 0.04))
			PixelArt.fill(img, tx, ty, 1, 16, Color(1, 1, 1, 0.04))
			PixelArt.fill(img, tx, ty + 15, 16, 1, Color(0, 0, 0, 0.35))
			PixelArt.fill(img, tx + 15, ty, 1, 16, Color(0, 0, 0, 0.35))
	_motif(b, img, rn, B)
	for mm in mono(cx, cy):
		var x: float = (mm.x - cx * FCH) / FPX
		var y: float = (mm.y - cy * FCH) / FPX
		var r: float = mm.r / FPX
		PixelArt.fill_ellipse(img, x + 3.0, y + 4.0, r * 1.05, r * 0.9, Color(0, 0, 0, 0.5))
	var sd := [[bio(cx - 1, cy), 0, 0, 3, FAR], [bio(cx + 1, cy), FAR - 3, 0, 3, FAR], [bio(cx, cy - 1), 0, 0, FAR, 3], [bio(cx, cy + 1), 0, FAR - 3, FAR, 3]]
	for q in sd:
		if q[0] != b:
			PixelArt.fill(img, q[1], q[2], q[3], q[4], Color(0, 0, 0, 0.6))
			var cc := Color(B.c)
			cc.a = 0.45
			for i in range(0, FAR, 6):
				if q[3] == 3:
					PixelArt.fill(img, q[1] + 1, i, 1, 3, cc)
				else:
					PixelArt.fill(img, i, q[2] + 1, 3, 1, cc)
	var e := {"c": ImageTexture.create_from_image(img), "u": t, "b": b}
	ch[k] = e
	if ch.size() > 40:
		var ok = null
		var ou := 1e18
		for kk in ch.keys():
			if ch[kk].u < ou:
				ou = ch[kk].u
				ok = kk
		ch.erase(ok)
	return e


func _motif(b: int, g2: Image, rn: PixelArt.Lcg, B: Dictionary) -> void:
	var c := Color(B.c)
	match b:
		0:   # NÚCLEO: trilhas de circuito
			for i in 5:
				var x := rn.i(10) * 16
				var y := rn.i(10) * 16
				var d := rn.i(4)
				for s in 3:
					var L := 8 + rn.i(5) * 8
					for j in L:
						PixelArt.px(g2, x, y, Draw.alpha(c, 0.3))
						x += [1, 0, -1, 0][d]
						y += [0, 1, 0, -1][d]
					d = (d + (1 if rn.next() < 0.5 else 3)) % 4
				PixelArt.fill(g2, x - 1, y - 1, 3, 3, Draw.alpha(c, 0.75))
		1:   # VÓRTEX: anéis
			for i in 3:
				var cx := rn.next() * FAR
				var cy := rn.next() * FAR
				var r := 10.0 + rn.next() * 34.0
				var a0 := rn.next() * TAU
				var a1 := a0 + 1.0 + rn.next() * 3.0
				var a := a0
				while a < a1:
					if int(a * r / 4.0) % 2:
						PixelArt.px(g2, roundi(cx + cos(a) * r), roundi(cy + sin(a) * r), Draw.alpha(c, 0.32))
					a += 1.4 / r
			for i in 6:
				PixelArt.fill(g2, rn.i(FAR), rn.i(FAR), 2, 2, Draw.alpha(c, 0.6))
		2:   # FORJA: grades e fissuras de lava
			for i in 2:
				var x := rn.i(8) * 16 + 2
				var y := rn.i(8) * 16 + 4
				PixelArt.fill(g2, x, y, 12, 8, "#0a0503")
				for k in range(1, 12, 2):
					PixelArt.fill(g2, x + k, y + 1, 1, 6, "#2b1810")
			for i in 3:
				var x := rn.next() * FAR
				var y := rn.next() * FAR
				var a := rn.next() * TAU
				var n := 22.0 + rn.next() * 28.0
				var j := 0
				while j < n:
					a += (rn.next() - 0.5) * 0.9
					x += cos(a)
					y += sin(a)
					PixelArt.px(g2, roundi(x) + 1, roundi(y) + 1, "#200a04")
					PixelArt.px(g2, roundi(x), roundi(y), Draw.alpha(c, 0.55))
					j += 1
		3:   # ABISMO: rede orgânica e esporos
			for i in 6:
				var x := rn.next() * FAR
				var y := rn.next() * FAR
				var a := rn.next() * TAU
				var w := (rn.next() - 0.5) * 0.25
				for j in 40:
					a += w + (rn.next() - 0.5) * 0.2
					x += cos(a) * 1.2
					y += sin(a) * 1.2
					PixelArt.px(g2, roundi(x), roundi(y), Draw.alpha(c, 0.2))
			for i in 10:
				PixelArt.px(g2, rn.i(FAR), rn.i(FAR), Draw.alpha(c, 0.55))
		4:   # SINGULARIDADE: estrelas e raios
			for i in 34:
				var cc := Color("#fff6d0") if rn.next() < 0.7 else c
				cc.a = 0.25 + rn.next() * 0.5
				PixelArt.px(g2, rn.i(FAR), rn.i(FAR), cc)
			for i in 2:
				var a := rn.next() * TAU
				for r in range(8, 70):
					PixelArt.px(g2, roundi(FAR / 2.0 + cos(a) * r), roundi(FAR / 2.0 + sin(a) * r), Draw.alpha(c, 0.18))


func update(dt: float) -> void:
	t += dt
	var P: PlayerState = g.player
	maxd = maxf(maxd, Vector2(P.x - o.x, P.y - o.y).length())
	if anc.is_empty():
		nt -= dt
		if nt <= 0.0:
			_anchor()
	else:
		var ins: bool = Vector2(P.x - anc.x, P.y - anc.y).length() < anc.r
		sync = ins
		if ins:
			anc.p += dt
			anc.w -= dt
			if anc.w <= 0.0:
				anc.w = 2.8
				_ring()
		else:
			anc.p = maxf(0.0, anc.p - dt * 0.4)
		if anc.p >= anc.need:
			_done()
	var v: Rect2 = ar.view_rect()
	var c := v.get_center()
	var D := v.size.length()
	for i in range(g.enemies.size() - 1, -1, -1):
		var e: Enemy = g.enemies[i]
		if e.bd.is_empty() and Vector2(e.x - c.x, e.y - c.y).length() > D * 1.6:
			g.enemies.remove_at(i)
	for arr in [g.projectiles, g.enemy_projectiles]:
		for i in range(arr.size() - 1, -1, -1):
			var p: Projectile = arr[i]
			if absf(p.x - c.x) > D or absf(p.y - c.y) > D:
				arr.remove_at(i)
	for i in range(g.pickups.size() - 1, -1, -1):
		var p: Dictionary = g.pickups[i]
		if Vector2(p.x - c.x, p.y - c.y).length() > D * 2.5:
			g.pickups.remove_at(i)
	var m := 1.0 + 0.16 * dep
	for e in g.enemies:
		if not e.fz and e.bd.is_empty():
			e.fz = true
			e.hp *= m
			e.max_hp *= m


func _anchor() -> void:
	var P: PlayerState = g.player
	var a := randf() * TAU
	var d := 1100.0 + randf() * 500.0
	var x := P.x + cos(a) * d
	var y := P.y + sin(a) * d
	for k in 8:
		var cx := floori(x / FCH)
		var cy := floori(y / FCH)
		var hit := false
		for j in range(-1, 2):
			for i in range(-1, 2):
				for q in mono(cx + i, cy + j):
					if Vector2(q.x - x, q.y - y).length() < q.r + 150.0:
						hit = true
		if not hit:
			break
		x += 110.0
		y += 70.0
	anc = {"x": x, "y": y, "r": 130.0, "p": 0.0, "need": 12.0 + dep * 1.5, "w": 1.0}
	g.sfx("anc")
	g.banner("ÂNCORA DETECTADA", Color("#b78cff"), 1.8)


func _ring() -> void:
	var n := mini(10, 4 + dep)
	for i in n:
		var a := float(i) / n * TAU + randf()
		var R := 400.0
		var tp := "tank" if dep > 2 and randf() < 0.25 else ("fast" if randf() < 0.5 else "basic")
		g.enemies.append(Enemy.new(anc.x + cos(a) * R, anc.y + sin(a) * R, tp))


func _done() -> void:
	var a := anc
	anc = {}
	dep += 1
	nt = 7.0
	best = maxi(best, dep)
	var P: PlayerState = g.player
	P.hp = minf(P.max_hp, P.hp + P.max_hp * 0.3)
	P.xp += P.xp_to_next * 0.5
	g.score += 250 * dep
	g.banner("ÂNCORA ESTABILIZADA · PROFUNDIDADE %d" % dep, Color("#b78cff"), 2.4)
	g.sfx("anc")
	g.shake(6.0)
	g.fx.burst(a.x, a.y, Color("#b78cff"), 40, 360.0)
	g.fx.ripple(a.x, a.y, 20.0, a.r * 2.0, Color("#b78cff"), 0.9, 0.7)
	g.cfg.elite = minf(0.35, float(el0 if el0 != null else 0.0) + 0.04 * dep)
	var r := SaveSystem.records()
	if dep > r.fenda:
		r.fenda = dep
		SaveSystem.write_records(r)
	Events.fenda_anchor.emit(dep)
	g.check_level_up()


func draw_floor(c: CanvasItem) -> void:
	bud = 1
	var v: Rect2 = ar.view_rect()
	var M := 220.0
	for j in range(floori((v.position.y - M) / FCH), floori((v.end.y + M) / FCH) + 1):
		if bud <= 0:
			break
		for i in range(floori((v.position.x - M) / FCH), floori((v.end.x + M) / FCH) + 1):
			if bud <= 0:
				break
			_chunk(i, j)
	bud = 1
	for j in range(floori(v.position.y / FCH), floori(v.end.y / FCH) + 1):
		for i in range(floori(v.position.x / FCH), floori(v.end.x / FCH) + 1):
			var e = _chunk(i, j)
			if e != null:
				c.draw_texture_rect(e.c, Rect2(i * FCH, j * FCH, FCH, FCH), false)
			else:
				c.draw_rect(Rect2(i * FCH, j * FCH, FCH, FCH), Color(FBI[bio(i, j)].a))
	if not anc.is_empty() and anc.x > v.position.x - 200.0 and anc.x < v.end.x + 200.0 and anc.y > v.position.y - 200.0 and anc.y < v.end.y + 200.0:
		var k: float = anc.p / anc.need
		var ac := Vector2(anc.x, anc.y)
		Draw.circle(c, ac, anc.r, Color(0.72, 0.55, 1, 0.18 + 0.1 * sin(t * 3.0)))
		Draw.dashed_ring(c, ac, anc.r, 12.0, 8.0, -t * 24.0, Color(0.72, 0.55, 1, 0.85), 2.0)
		Draw.arc(c, ac, anc.r - 10.0, -PI / 2.0, -PI / 2.0 + k * TAU, Color(1, 1, 1, 0.9), 6.0)


func draw_monoliths(c: CanvasItem) -> void:
	var v: Rect2 = ar.view_rect()
	for q in ar.near:
		if q.x < v.position.x - 60.0 or q.x > v.end.x + 60.0 or q.y < v.position.y - 60.0 or q.y > v.end.y + 60.0:
			continue
		var B: Dictionary = FBI[q.b]
		var col := Color(B.c)
		var ctr := Vector2(q.x, q.y)
		var r: float = q.r
		var oc := Draw.reg(8, r, q.s, ctr)
		Draw.poly(c, oc, Color("#07070c"))
		Draw.poly_stroke(c, oc, Draw.alpha(col, 0.8), 2.0)
		for i in range(0, 8, 2):
			var a: float = i * TAU / 8.0 + q.s
			c.draw_line(ctr + Vector2(cos(a), sin(a)) * r * 0.42, ctr + Vector2(cos(a), sin(a)) * r, Draw.alpha(col, 0.3), 1.0, true)
		Draw.poly(c, Draw.reg(8, r * 0.42, q.s, ctr), Draw.alpha(col, 0.3 + 0.2 * sin(t * 2.0 + q.s * 9.0)))


func draw_hud(c: CanvasItem) -> void:
	var vw: float = g.vw
	var vh: float = g.vh
	var col := Color("#b78cff")
	Draw.text(c, Assets.font_mono_bold, "FENDA · PROFUNDIDADE %d · %d m" % [dep, roundi(maxd / 32.0)], Vector2(vw / 2.0, vh - 22.0), 11, Draw.alpha(col, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	if not anc.is_empty() and anc.p > 0.0:
		var w := minf(220.0, vw * 0.5)
		var k: float = anc.p / anc.need
		c.draw_rect(Rect2(vw / 2.0 - w / 2.0, vh - 46.0, w, 6.0), Color(1, 1, 1, 0.12))
		c.draw_rect(Rect2(vw / 2.0 - w / 2.0, vh - 46.0, w * k, 6.0), col)
		Draw.text(c, Assets.font_mono_bold, ("SINCRONIZANDO %d%%" if sync else "ÂNCORA %d%%") % roundi(k * 100.0), Vector2(vw / 2.0, vh - 52.0), 11, Draw.alpha(col, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
