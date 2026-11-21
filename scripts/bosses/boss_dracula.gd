class_name BossDracula
extends BossBase
## DRÁCULA · Catedral Carmesim (força 6 · estranheza 3). Elegante e ameaçador.
## Assinatura: o LAÇO DE SANGUE (drena a vida em linha reta; quebre a linha de visão atrás de bancos, pilares
## e caixões, ou role no momento certo). Fase 2 (Lua de Sangue): as velas se apagam, a visão encolhe,
## forma de morcego e caixões que soltam morcegos.

const DRC := {"lance": {"tw": 0.75, "n": 3, "sd": 0.2, "sp": 430.0, "dmg": 12.0}, "mist": {"tw": 0.9, "dmg": 22.0},
	"drain": {"aim": 1.1, "max": 3.2, "tick": 0.5, "dmg": 6.0, "heal": 0.012, "stun": 1.5}, "gap": [1.5, 1.05]}
const RED := Color("#ff1744")
const ROSE := Color("#ff4466")


func on_spawn(b: Enemy) -> void:
	b.d = {"cur": "", "s": 0, "pt": 0.0, "tet": {}, "bat": 0.0, "lp": ""}


func ai(b: Enemy, dt: float, ph: int) -> void:
	var D: Dictionary = b.d
	if b.stun > 0.0:
		b.vuln = 1.5
		return
	b.vuln = 1.0
	if not D.tet.is_empty():
		_tether(b, dt)
		return
	if D.cur != "":
		D.pt += dt
		if _run(b, dt, ph):
			D.cur = ""
			D.s = 0
			b.cd = float(DRC.gap[1 if ph else 0]) / float(g.cfg.bossRate)
	else:
		if D.bat > 0.0:
			D.bat -= dt
			bmv(b, dt, g.player.x + cos(b.t * 2.4) * 190.0, g.player.y + sin(b.t * 3.1) * 130.0, 1.9)
		else:
			var a := b.t * 0.45
			var R0 := 260.0
			bmv(b, dt, g.player.x + cos(a) * R0, g.player.y - absf(sin(a)) * R0 * 0.8 - 60.0, 1.0)
		b.cd -= dt
		if b.cd <= 0.0:
			var L := ["lance", "mist", "bats", "drain", "lance"] if ph else ["lance", "mist", "bats", "drain"]
			var n: String = L[randi() % L.size()]
			while n == D.lp and L.size() > 1:
				n = L[randi() % L.size()]
			D.lp = n
			D.cur = n
			D.pt = 0.0
			D.s = 0
	if b.vis != 0 and not b.no_touch and dist_to_player(b) < b.radius * 0.8 + g.player.radius:
		g.contact(float(b.bd.cd) * float(g.cfg.bossDmg), b)


func _run(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	match String(D.cur):
		"lance":
			var C: Dictionary = DRC.lance
			if D.s == 0:
				D.s = 1
				b.chg = C.tw
				g.sfx("blink")
			if D.s == 1 and D.pt > C.tw:
				D.s = 2
				var a := ang_to_player(b)
				var n: int = C.n + (2 if ph else 0)
				for i in n:
					bolt(b.x, b.y, a + (i - (n - 1) / 2.0) * C.sd, C.sp, RED, C.dmg, 6.0, {"shard": true, "pry": true, "src": b})
				g.sfx("bossfire")
			if ph and D.s == 2 and D.pt > C.tw + 0.55:
				D.s = 3
				var a := ang_to_player(b)
				for i in 3:
					bolt(b.x, b.y, a + (i - 1) * 0.12, C.sp * 1.1, RED, C.dmg, 6.0, {"shard": true, "pry": true, "src": b})
			return D.pt > C.tw + (1.1 if ph else 0.7)
		"mist":   # some na névoa e reaparece atrás do Nick com um corte aparável
			var C: Dictionary = DRC.mist
			if D.s == 0:
				D.s = 1
				b.vis = 0
				b.inv = C.tw + 0.2
				g.fx.burst(b.x, b.y, Color("#7a0b25"), 18, 160.0)
				var B := box()
				D.tx = clampf(g.player.x - cos(g.player.angle) * 130.0, B.position.x + 40.0, B.end.x - 40.0)
				D.ty = clampf(g.player.y - sin(g.player.angle) * 130.0, B.position.y + 40.0, B.end.y - 40.0)
				var sa := atan2(g.player.y - D.ty, g.player.x - D.tx)
				hz({"k": "b", "x": D.tx, "y": D.ty, "x2": D.tx + cos(sa) * 170.0, "y2": D.ty + sin(sa) * 170.0, "ang": sa, "om": 1.0 if randf() < 0.5 else -1.0, "w": 70.0, "tw": C.tw, "ta": 0.14, "dmg": C.dmg, "col": ROSE, "slash": true, "ml": true, "bsrc": b})
				hz({"k": "c", "x": D.tx, "y": D.ty, "r": 34.0, "tw": C.tw - 0.05, "ta": 0.02, "dmg": 0.0, "col": ROSE})
			if D.s == 1 and D.pt > C.tw - 0.1:
				D.s = 2
				b.vis = 1
				b.x = D.tx
				b.y = D.ty
				g.fx.burst(b.x, b.y, ROSE, 16, 200.0)
				g.sfx("rhswipe")
			return D.pt > C.tw + 0.6
		"bats":
			var v := int(D.pt / 0.4)
			if v >= D.s and v < 3 + (1 if ph else 0):
				D.s = v + 1
				ring(b, 8 + ph * 2, 180.0, ROSE, v * 0.4, 7.0)
				g.sfx("blink")
			return D.pt > 1.7
		"drain":
			if D.s == 0:
				D.s = 1
				D.tet = {"t": 0.0, "st": "aim", "k": 0.0}
				g.banner("LAÇO DE SANGUE · QUEBRE A LINHA DE VISÃO", Color("#ff2b55"), 2.0)
				g.sfx("phase")
			return true
	return true


func _tether(b: Enemy, dt: float) -> void:
	var T: Dictionary = b.d.tet
	var C: Dictionary = DRC.drain
	T.t += dt
	var P: PlayerState = g.player
	var blk: bool = g.arena.seg_hit(b.x, b.y, P.x, P.y, 3.0) != null or dist_to_player(b) > 760.0
	if T.st == "aim":
		if T.t >= C.aim:
			T.st = "drain"
			T.t = 0.0
			g.sfx("vapor")
	else:
		if blk or (P.is_dashing and T.t > 0.3):
			b.d.tet = {}
			b.stun = C.stun
			g.sfx("parry")
			g.shake(4.0)
			g.banner("O LAÇO SE PARTIU", Color("#ffd23d"), 1.4)
			g.fx.burst(b.x, b.y, Color("#ff2b55"), 24, 260.0)
			return
		T.k += dt
		if T.k >= C.tick:
			T.k = 0.0
			g.take_damage(C.dmg * float(g.cfg.bossDmg), "area")
			b.hp = minf(b.max_hp, b.hp + b.max_hp * C.heal)
			g.fx.burst(P.x, P.y, Color("#ff2b55"), 6, 120.0)
		if T.t >= C.max:
			b.d.tet = {}
			b.cd = 1.2


func on_phase(b: Enemy, ph: int) -> void:
	if ph == 1:
		b.d.bat = 8.0
		g.banner("LUA DE SANGUE", Color("#ff2b55"), 2.2)
		g.sfx("phase")
		g.shake(6.0)
		var A = g.arena.cur
		if A != null:
			A.dark = true


# ======================================================================
# desenho (vetorial, como no HTML)
# ======================================================================
func _bat(c: CanvasItem, x: float, y: float, s: float, f: float, al: float) -> void:
	var pts := PackedVector2Array([Vector2(x, y)])
	Draw.quad_to(pts, Vector2(x, y), Vector2(x - s * 0.8, y - s * (0.6 + f)), Vector2(x - s * 1.4, y - s * 0.1), 5)
	Draw.quad_to(pts, pts[-1], Vector2(x - s * 0.9, y + s * 0.1), Vector2(x - s * 0.6, y + s * 0.3), 4)
	Draw.quad_to(pts, pts[-1], Vector2(x - s * 0.3, y + s * 0.1), Vector2(x, y + s * 0.3), 4)
	Draw.quad_to(pts, pts[-1], Vector2(x + s * 0.3, y + s * 0.1), Vector2(x + s * 0.6, y + s * 0.3), 4)
	Draw.quad_to(pts, pts[-1], Vector2(x + s * 0.9, y + s * 0.1), Vector2(x + s * 1.4, y - s * 0.1), 4)
	Draw.quad_to(pts, pts[-1], Vector2(x + s * 0.8, y - s * (0.6 + f)), Vector2(x, y), 5)
	pts.remove_at(pts.size() - 1)
	_safe_poly(c, pts, Color(0.106, 0.04, 0.07, al))
	c.draw_rect(Rect2(x - s * 0.25, y - s * 0.1, 2, 2), Color(1, 0.17, 0.33, al))
	c.draw_rect(Rect2(x + s * 0.15, y - s * 0.1, 2, 2), Color(1, 0.17, 0.33, al))


func _safe_poly(c: CanvasItem, pts: PackedVector2Array, col: Color, cols: PackedColorArray = PackedColorArray()) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	if cols.is_empty():
		c.draw_colored_polygon(pts, col)
	else:
		c.draw_polygon(pts, cols)


func draw(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var t := b.t
	var att := b.chg > 0.0 or b.ph > 0
	var al := b.al
	c.draw_set_transform(Vector2(b.x, b.y), 0.0, Vector2(b.sc, b.sc))
	for i in 3:
		Draw.ellipse(c, Vector2(sin(t * 1.3 + i) * 14.0, 50.0 + i * 3.0), 46.0 - i * 8.0, 9.0, Color(0.47, 0, 0.12, 0.22 * al))
	if b.d.bat > 0.0:
		_bat(c, 0, 0, 40, sin(t * 22.0) * 0.5, al)
		for i in 4:
			_bat(c, cos(t * 2.0 + i * 1.6) * 58.0, sin(t * 2.6 + i * 1.6) * 34.0, 10, sin(t * 20.0 + i), al)
		Draw.circle(c, Vector2(0, 4), 10.0, Color(0.29, 0.055, 0.13, al))
	else:
		var w := sin(t * 3.0) * 0.1
		# capa: gradiente vertical #14060c → #7a0f2c
		var cape := PackedVector2Array([Vector2(-14, -26)])
		Draw.quad_to(cape, Vector2(-14, -26), Vector2(-60, 10), Vector2(-54 + w * 30.0, 44), 6)
		for i in 6:
			cape.append(Vector2(-54.0 + i * 21.6 + 10.8, (30.0 if i % 2 else 48.0) + sin(t * 4.0 + i) * 5.0))
		cape.append(Vector2(54 - w * 30.0, 44))
		Draw.quad_to(cape, Vector2(54 - w * 30.0, 44), Vector2(60, 10), Vector2(14, -26), 6)
		var cc := PackedColorArray()
		for p in cape:
			cc.append(Color("#14060c").lerp(Color("#7a0f2c"), clampf((p.y + 30.0) / 80.0, 0.0, 1.0)) * Color(1, 1, 1, al))
		_safe_poly(c, cape, Color.WHITE, cc)
		var body := PackedVector2Array([Vector2(-10, -20)])
		Draw.quad_to(body, Vector2(-10, -20), Vector2(-34, 10), Vector2(-30, 40), 6)
		body.append(Vector2(30, 40))
		Draw.quad_to(body, Vector2(30, 40), Vector2(34, 10), Vector2(10, -20), 6)
		_safe_poly(c, body, Color(1, 1, 1, al) if b.flash > 0.0 else Color(0.61, 0.07, 0.22, al))
		Draw.poly(c, PackedVector2Array([Vector2(-20, -22), Vector2(-30, -44), Vector2(-8, -26)]), Color(0.05, 0.02, 0.035, al))
		Draw.poly(c, PackedVector2Array([Vector2(20, -22), Vector2(30, -44), Vector2(8, -26)]), Color(0.05, 0.02, 0.035, al))
		var vest := PackedVector2Array([Vector2(-22, -18)])
		Draw.quad_to(vest, Vector2(-22, -18), Vector2(0, -30), Vector2(22, -18), 6)
		vest.append_array([Vector2(16, 22), Vector2(-16, 22)])
		_safe_poly(c, vest, Color(0.1, 0.04, 0.07, al))
		Draw.circle(c, Vector2(0, -6), 6.0, Draw.alpha(RED, 0.3 * al))
		Draw.circle(c, Vector2(0, -6), 3.5, Draw.alpha(RED, al))
		var head := Draw.ellipse_pts(Vector2(0, -28), 10, 12, 0.0, 24)
		var hc := PackedColorArray()
		for p in head:
			hc.append(Color("#efe9df").lerp(Color("#c9c0b4"), clampf((p.y + 40.0) / 28.0, 0.0, 1.0)) * Color(1, 1, 1, al))
		c.draw_polygon(head, hc)
		var hair := PackedVector2Array([Vector2(-11, -26)])
		Draw.quad_to(hair, Vector2(-11, -26), Vector2(-12, -44), Vector2(0, -42), 5)
		Draw.quad_to(hair, Vector2(0, -42), Vector2(12, -44), Vector2(11, -26), 5)
		Draw.quad_to(hair, Vector2(11, -26), Vector2(4, -34), Vector2(0, -31), 4)
		Draw.quad_to(hair, Vector2(0, -31), Vector2(-4, -34), Vector2(-11, -26), 4)
		hair.remove_at(hair.size() - 1)
		_safe_poly(c, hair, Color(0.03, 0.016, 0.04, al))
		Draw.poly(c, PackedVector2Array([Vector2(-7, -28), Vector2(-2, -27), Vector2(-7, -25.5)]), Draw.alpha(RED, al))
		Draw.poly(c, PackedVector2Array([Vector2(7, -28), Vector2(2, -27), Vector2(7, -25.5)]), Draw.alpha(RED, al))
		c.draw_rect(Rect2(-3, -21, 6, 2), Color(0.29, 0.04, 0.08, al))
		if att:
			Draw.poly(c, PackedVector2Array([Vector2(-3, -19), Vector2(-1.5, -15), Vector2(0, -19)]), Color(1, 1, 1, al))
			Draw.poly(c, PackedVector2Array([Vector2(0, -19), Vector2(1.5, -15), Vector2(3, -19)]), Color(1, 1, 1, al))
		if b.chg > 0.0:
			for s in [-1.0, 1.0]:
				c.draw_line(Vector2(s * 20, -8), Vector2(s * 44, -18), Color(0.94, 0.91, 0.87, al), 2.0, true)
				for k in 3:
					c.draw_line(Vector2(s * 44, -18), Vector2(s * (52 + k * 2), -24 + k * 6), Color(0.94, 0.91, 0.87, al), 2.0, true)
		for i in 3:
			_bat(c, cos(t * 1.7 + i * 2.1) * 66.0, sin(t * 2.1 + i * 2.1) * 40.0 - 8.0, 7, sin(t * 16.0 + i), al)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_top(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var T: Dictionary = b.d.tet
	var P: PlayerState = g.player
	if not T.is_empty():
		var dr: bool = T.st == "drain"
		var a := Vector2(b.x, b.y - 20.0)
		var e := Vector2(P.x, P.y)
		var col := Color(1, 0.17, 0.33, 0.85 if dr else 0.35 + 0.35 * sin(g.game_time * 30.0))
		if dr:
			c.draw_line(a, e, col, 5.0, true)
			for i in 6:
				var k := 1.0 - fmod(g.game_time * 1.6 + i / 6.0, 1.0)
				var p := a + (e - a) * k
				c.draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), Color("#ff6a8a"))
		else:
			Draw.dashed_line(c, a, e, 6.0, 6.0, 0.0, col, 1.5)
	if b.stun > 0.0:
		Draw.text(c, Assets.font_mono_bold, "ATORDOADO", Vector2(b.x, b.y - 64.0), 12, Color(1, 0.82, 0.24, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


## Os olhos dele continuam visíveis na escuridão.
func draw_after_dark(c: CanvasItem, b: Enemy) -> void:
	var A = g.arena.cur
	if A == null or A.id != "catedral" or not A.get("dark", false) or b.vis == 0 or b.hp <= 0.0:
		return
	c.draw_rect(Rect2(b.x - 8, b.y - 30, 4, 3), Color(1, 0.09, 0.27, 0.95))
	c.draw_rect(Rect2(b.x + 4, b.y - 30, 4, 3), Color(1, 0.09, 0.27, 0.95))
