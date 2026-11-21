class_name Hazards
extends RefCounted
## Áreas de perigo com aviso (HZ, hz(), hzUpd(), hzDraw() do HTML v3.6).
## Tipos: 'c' círculo, 'r' anel que se expande, 'b' faixa/raio (pode seguir uma fonte e girar), 'w' leque de aviso.
## Todo perigo avisa (tw) antes de causar dano (ta).

var g
var list: Array[Dictionary] = []


func _init(game) -> void:
	g = game


func clear() -> void:
	list.clear()


func add(o: Dictionary) -> Dictionary:
	if list.size() >= 40:
		return {}
	var h := {"t": 0.0, "tw": 1.0, "ta": 0.3, "dmg": 20.0, "dps": 0.0, "col": Color("#ff3d6a"), "x": 0.0, "y": 0.0, "x2": 0.0, "y2": 0.0, "w": 20.0, "r": 40.0}
	h.merge(o, true)
	list.append(h)
	return h


static func seg_d(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var dx := x2 - x1
	var dy := y2 - y1
	var l := dx * dx + dy * dy
	if l == 0.0:
		l = 1.0
	var t := clampf(((px - x1) * dx + (py - y1) * dy) / l, 0.0, 1.0)
	return Vector2(px - x1 - t * dx, py - y1 - t * dy).length()


func update(dt: float) -> void:
	var P: PlayerState = g.player
	var bdm: float = g.cfg.bossDmg
	for i in range(list.size() - 1, -1, -1):
		var h: Dictionary = list[i]
		h.t += dt
		if h.has("src") and h.src != null:
			var s = h.src
			h.x = s.x
			h.y = s.y
			h.ang = float(h.get("ang", 0.0)) + float(h.get("om", 0.0)) * dt
			var L: float = h.get("len", 1000.0)
			h.x2 = h.x + cos(h.ang) * L
			h.y2 = h.y + sin(h.ang) * L
		if h.t >= h.tw and h.t < h.tw + h.ta:
			var d := Vector2(P.x - h.x, P.y - h.y).length()
			var hit := false
			match h.k:
				"c": hit = d < h.r + P.radius * 0.5
				"r": hit = absf(d - h.r * minf(1.0, (h.t - h.tw) / h.ta)) < 16.0 + P.radius * 0.5
				"w": hit = false
				_: hit = seg_d(P.x, P.y, h.x, h.y, h.x2, h.y2) < h.w / 2.0 + P.radius * 0.6
			if hit and not g.try_parry_hazard(h):
				var melee: bool = h.get("slash", false) or h.get("ml", false)
				if h.dps > 0.0:
					if melee:
						g.contact(h.dps * bdm, h.get("bsrc"))
					else:
						g.take_damage(h.dps * bdm * dt, "area")
				elif not h.get("hit", false):
					h.hit = true
					if h.dmg > 0.0:
						g.take_damage(h.dmg * bdm, "melee" if melee else "area")
		if h.t >= h.tw + h.ta:
			list.remove_at(i)


func draw(c: CanvasItem) -> void:
	for h in list:
		_draw_one(c, h)
	if Settings.s.cb:   # alto contraste: contorno branco nas áreas que ainda vão ativar
		for h in list:
			if h.t >= h.tw:
				continue
			var col := Color(1, 1, 1, 0.9)
			match h.k:
				"c", "r": Draw.dashed_ring(c, Vector2(h.x, h.y), h.r, 5.0, 4.0, 0.0, col, 2.0)
				"b": Draw.dashed_line(c, Vector2(h.x, h.y), Vector2(h.x2, h.y2), 5.0, 4.0, 0.0, col, 2.0)


func _draw_one(c: CanvasItem, h: Dictionary) -> void:
	var act: bool = h.t >= h.tw
	var k := minf(1.0, h.t / maxf(h.tw, 0.0001))
	var col: Color = h.col
	var tm: float = h.t
	var o := Vector2(h.x, h.y)
	if h.k == "w":
		var a0: float = h.ang - h.half
		var a1: float = h.ang + h.half
		Draw.radial_fan(c, o, h.r, Color(col, 0.0), Color(col, 0.12 + 0.2 * k), a0, a1)
		var sa := 0.4 + 0.4 * absf(sin(tm * 14.0))
		var edge := Draw.alpha(col, sa)
		Draw.dashed_arc(c, o, h.r, a0, a1, 8.0, 6.0, -tm * 40.0, edge, 2.0)
		Draw.dashed_line(c, o, o + Vector2(cos(a0), sin(a0)) * h.r, 8.0, 6.0, -tm * 40.0, edge, 2.0)
		Draw.dashed_line(c, o, o + Vector2(cos(a1), sin(a1)) * h.r, 8.0, 6.0, -tm * 40.0, edge, 2.0)
		Draw.arc(c, o, h.r * k, a0, a1, Draw.alpha(col, 0.8 * k), 3.0)
		return
	if not act:
		if h.k == "b":
			var e2 := Vector2(h.x2, h.y2)
			var L := maxf(o.distance_to(e2), 1.0)
			var u := (e2 - o) / L
			var nrm := Vector2(-u.y, u.x)
			var hw: float = h.w / 2.0
			Draw.poly(c, PackedVector2Array([o + nrm * hw, e2 + nrm * hw, e2 - nrm * hw, o - nrm * hw]), Draw.alpha(col, 0.1 + 0.14 * k))
			for sg in [-1.0, 1.0]:
				Draw.dashed_line(c, o + nrm * hw * sg, e2 + nrm * hw * sg, 12.0, 9.0, -tm * 90.0, Draw.alpha(col, 0.55), 2.0)
			var n := mini(14, int(L / 60.0))
			var ca := Draw.alpha(col, 0.45 + 0.35 * k)
			for i in n:
				var dd := fmod(tm * 2.2 + float(i) / n, 1.0) * L
				var pp := o + u * dd
				var s := hw * 0.45
				c.draw_polyline(PackedVector2Array([pp - u * 10.0 + nrm * s, pp + u * 6.0, pp - u * 10.0 - nrm * s]), ca, 3.0, true)
		else:
			var r: float = h.r
			Draw.radial_fan(c, o, r, Draw.alpha(col, 0.16 * k), Color(col, 0.0))
			Draw.dashed_ring(c, o, r, 8.0, 6.0, tm * 40.0, Draw.alpha(col, 0.35 + 0.3 * absf(sin(tm * 14.0))), 2.0)
			Draw.ring(c, o, r * (1.0 - k) + 4.0, Draw.alpha(col, 0.8), 2.0)
			c.draw_line(o - Vector2(r * 0.3, 0), o + Vector2(r * 0.3, 0), Draw.alpha(col, 0.8), 2.0, true)
			c.draw_line(o - Vector2(0, r * 0.3), o + Vector2(0, r * 0.3), Draw.alpha(col, 0.8), 2.0, true)
		return
	var u_: float = (h.t - h.tw) / maxf(h.ta, 0.0001)
	match h.k:
		"c":
			var a := maxf(0.0, 0.95 - u_ * 0.5)
			Draw.radial_fan(c, o, h.r, Color(1, 1, 1, a), Draw.alpha(col, a))
			Draw.ring(c, o, h.r, Color(1, 1, 1, a), 3.0)
			if h.get("spk", false):
				g.rhino_fx(c, 3, h.x, h.y + h.r * 0.5, 1.1, maxf(0.0, 1.0 - u_))
		"r":
			var r: float = h.r * minf(1.0, u_)
			Draw.ring(c, o, r, Draw.alpha(col, 0.9), 14.0)
			Draw.ring(c, o, r, Color(1, 1, 1, 0.9), 4.0)
			if h.get("rng", false):
				var ex: Array = Assets.rhino_frame("extras", 2)
				if not ex.is_empty():
					g.rhino_fx(c, 2, h.x, h.y, r * 2.0 / float(ex[2]), 0.5 * minf(1.0, r / 150.0) * (1.0 - u_ * 0.5))
		_:
			var e2 := Vector2(h.x2, h.y2)
			var L := maxf(o.distance_to(e2), 1.0)
			var uu := (e2 - o) / L
			var nrm := Vector2(-uu.y, uu.x)
			var fl := 0.85 + 0.15 * sin(tm * 60.0)
			var seg := func(p: float, q: float, w: float, al: float, st: Color) -> void:
				c.draw_line(o + uu * p, o + uu * q, Draw.alpha(st, al), w, true)
			if h.get("slash", false):
				var sg := -1.0 if float(h.get("om", 1.0)) < 0.0 else 1.0
				var tr := 0.95 * minf(1.0, u_ * 4.0)
				for i in 10:
					var u0 := i / 10.0
					var u1 := (i + 1) / 10.0
					var f := (1.0 - u0) * (1.0 - u0)
					var aa0: float = h.ang - sg * tr * u1
					var aa1: float = h.ang - sg * tr * u0
					Draw.sector(c, o, L, minf(aa0, aa1), maxf(aa0, aa1), Draw.alpha(col, 0.5 * f))
					Draw.arc(c, o, L - 2.0, minf(aa0, aa1), maxf(aa0, aa1), Color(1, 0.85, 0.8, 0.8 * f), 5.0)
				seg.call(26.0, L, h.w * 0.8, 0.3 * fl, col)
				seg.call(26.0, L, h.w * 0.34, 0.85, col)
				seg.call(34.0, L, 9.0, fl, Color.WHITE)
				Draw.radial_fan(c, e2, h.w * 0.8, Color(1, 1, 1, 0.9 * fl), Color(col, 0.0))
			else:
				seg.call(0.0, L, h.w * 2.0, 0.22 * fl, col)
				seg.call(0.0, L, h.w, 0.9, col)
				seg.call(0.0, L, h.w * 0.35, fl, Color.WHITE)
				var am := minf(h.w * 0.45, 12.0)
				var n := mini(26, int(L / 18.0)) + 2
				for q in 2:
					var pts := PackedVector2Array([o])
					for i in range(1, n + 1):
						var d := L * i / n
						pts.append(o + uu * d + nrm * (randf() - 0.5) * am)
					c.draw_polyline(pts, Color(1, 1, 1, 0.8), 2.0, true)
				Draw.radial_fan(c, o, h.w * 0.9, Color(1, 1, 1, 0.9 * fl), Color(col, 0.0))
	if not h.get("fx", false):
		h.fx = true
		if h.k != "b":
			g.fx.burst(h.x, h.y, col, 10, 260.0)
			if h.dmg >= 20.0:
				g.shake(2.0)
