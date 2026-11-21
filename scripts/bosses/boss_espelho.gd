class_name BossEspelho
extends BossBase
## ESPELHO · Galeria dos Reflexos (força 6 · estranheza 10). Chefe final do Classic.
## Ecos que repetem o caminho e os tiros do Nick de 3 s atrás; reflexos com comportamento próprio (só o
## verdadeiro tem sombra e acompanha o Nick com o olho); falsa abertura (núcleo brilhando com o olho FECHADO
## devolve os tiros); fase 2: o mundo se inverte (com contagem) e ele dispara o padrão da arma do próprio Nick.

const MRR := {"rec": 3.0, "gap": [1.6, 1.15], "fake": 2.2, "real": 1.6, "flip": 7.0, "flipEvery": 15.0}
const MAG := Color("#ff3df2")
const PINK := Color("#ffd6ff")

var hist: Array = []      # [tempo, x, y, ângulo, disparou]
var ech: Array[Dictionary] = []
var refl: Array[Dictionary] = []
var fake := 0.0
var real := 0.0
var flip_t := 4.0
var cnt := 0.0
var first := 0
var fk := false
var ln := 0
var _last_attack := -1e9


func _init(game) -> void:
	super(game)
	Events.boss_start.connect(func(_i: int): _reset())
	Events.boss_defeated.connect(func(_i: int, _n: String):
		g.mir_x = false
		ech.clear()
		refl.clear())


func _reset() -> void:
	hist.clear()
	ech.clear()
	refl.clear()
	fake = 0.0
	real = 0.0
	flip_t = 4.0
	cnt = 0.0


func clear_visuals() -> void:
	ech.clear()
	refl.clear()


func on_spawn(b: Enemy) -> void:
	b.d = {"cur": "", "s": 0, "pt": 0.0, "lp": ""}
	_reset()


## Alvo espelhado pelo centro da arena, sem sair do alcance da câmera (NF.mirrorT).
func mirror_target() -> Vector2:
	var B := box()
	var P: PlayerState = g.player
	var tx := B.position.x + B.end.x - P.x
	var ty := B.position.y + B.end.y - P.y
	var dx := tx - P.x
	var dy := ty - P.y
	var d := sqrt(dx * dx + dy * dy)
	var L := maxf(220.0, minf(g.vw, g.vh) / g.arena.cam.z * 0.72)
	if d > L:
		tx = P.x + dx / d * L
		ty = P.y + dy / d * L
	return Vector2(tx, ty)


func _record(dt: float) -> void:
	var P: PlayerState = g.player
	var fired := P.last_attack != _last_attack
	_last_attack = P.last_attack
	var ang: float = g.aim.ang if (g.aim.on or g.manual()) else P.angle
	hist.append([g.game_time, P.x, P.y, ang, 1 if fired else 0])
	while not hist.is_empty() and g.game_time - float(hist[0][0]) > MRR.rec + 0.2:
		hist.pop_front()


func ai(b: Enemy, dt: float, ph: int) -> void:
	var D: Dictionary = b.d
	var P: PlayerState = g.player
	_record(dt)
	var B := box()
	# reflexos com comportamento próprio
	for r in refl:
		r.t += dt
		if r.k == "m":
			r.x += ((B.position.x + B.end.x - P.x) - r.x) * minf(1.0, dt * 2.0)
			r.y += (P.y - r.y) * minf(1.0, dt * 2.0)
		else:
			var h = null
			for q in hist:
				if g.game_time - float(q[0]) < 1.2:
					h = q
					break
			if h != null:
				r.x += (h[1] - r.x) * minf(1.0, dt * 3.0)
				r.y += (h[2] - r.y) * minf(1.0, dt * 3.0)
		r.cd = (r.cd if r.has("cd") else 1.8) - dt
		if r.cd <= 0.0:
			r.cd = 2.2
			bolt(r.x, r.y, atan2(P.y - r.y, P.x - r.x), 260.0, PINK, 7.0, 5.0, {"src": b})
	# acertar um reflexo o estilhaça
	for i in range(refl.size() - 1, -1, -1):
		var r: Dictionary = refl[i]
		for j in range(g.projectiles.size() - 1, -1, -1):
			var p: Projectile = g.projectiles[j]
			if Vector2(p.x - r.x, p.y - r.y).length() < 22.0:
				g.projectiles.remove_at(j)
				refl.remove_at(i)
				g.sfx("crate")
				g.fx.burst(r.x, r.y, PINK, 18, 220.0)
				for k in 5:
					bolt(r.x, r.y, k * TAU / 5.0 + randf(), 210.0, PINK, 6.0, 4.0)
				break
	# ecos: o passado do Nick volta e atira de novo
	for i in range(ech.size() - 1, -1, -1):
		var e: Dictionary = ech[i]
		e.t += dt
		if e.t < 0.6:
			continue
		var tt: float = e.t0 + (e.t - 0.6)
		var h = null
		for q in e.h:
			if float(q[0]) >= tt:
				h = q
				break
		if h == null:
			ech.remove_at(i)
			continue
		e.x = h[1]
		e.y = h[2]
		if h[4] and h.size() < 6:
			h.append(true)
			bolt(e.x, e.y, h[3], 330.0, Color("#ff8af6"), 8.0, 5.0, {"src": b})
	if fake > 0.0:
		fake -= dt
		b.vuln = 1.0
		if fake <= 0.0:
			real = MRR.real
			g.sfx("key")
	elif real > 0.0:
		real -= dt
		b.vuln = 1.6
	else:
		b.vuln = 1.0
	if ph >= 1:
		flip_t -= dt
		if flip_t <= 0.0:
			if not g.mir_x:
				if cnt <= 0.0:
					cnt = 3.0
					g.banner("O MUNDO SE INVERTE EM 3", MAG, 1.0)
				else:
					cnt -= dt
					if cnt <= 0.0:
						g.mir_x = true
						flip_t = MRR.flip
						g.sfx("phase")
						g.shake(4.0)
					else:
						var n := ceili(cnt)
						if n != ln:
							ln = n
							g.banner("O MUNDO SE INVERTE EM %d" % n, MAG, 0.9)
							g.sfx("tink")
			else:
				g.mir_x = false
				flip_t = MRR.flipEvery
				cnt = 0.0
				g.banner("DE VOLTA", PINK, 1.0)
	if D.cur != "":
		D.pt += dt
		if _run(b, dt, ph):
			D.cur = ""
			D.s = 0
			b.cd = float(MRR.gap[1 if ph else 0]) / float(g.cfg.bossRate)
	else:
		var m := mirror_target()
		bmv(b, dt, m.x, m.y, 1.15)
		b.cd -= dt
		if b.cd <= 0.0:
			var L := ["echo", "copy", "fake", "refl", "copy"] if ph else ["echo", "refl", "fake", "burst"]
			var n: String = L[randi() % L.size()]
			while n == D.lp:
				n = L[randi() % L.size()]
			D.lp = n
			D.cur = n
			D.pt = 0.0
			D.s = 0
	if b.vis != 0 and dist_to_player(b) < b.radius * 0.8 + P.radius:
		g.contact(float(b.bd.cd) * float(g.cfg.bossDmg), b)


func _echo_from_history() -> void:
	if hist.size() > 8:
		var h := hist.duplicate(true)
		ech.append({"t": 0.0, "t0": float(h[0][0]), "h": h, "x": h[0][1], "y": h[0][2]})


func _run(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	match String(D.cur):
		"echo":
			if D.s == 0:
				D.s = 1
				_echo_from_history()
				if ph:
					g.get_tree().create_timer(1.2).timeout.connect(func():
						if g.enc.boss == b:
							_echo_from_history())
				g.sfx("blink")
				if first == 0:
					g.banner("SEUS PASSOS VOLTAM", Color("#ff8af6"), 1.4)
				first += 1
			return D.pt > 1.2
		"refl":
			if D.s == 0:
				D.s = 1
				if refl.size() < 2:
					refl.append({"k": "m", "x": b.x, "y": b.y, "t": 0.0, "hist": []})
					refl.append({"k": "d", "x": b.x, "y": b.y, "t": 0.0, "hist": []})
					g.sfx("mut")
					g.fx.burst(b.x, b.y, PINK, 20, 200.0)
			return D.pt > 0.8
		"fake":
			if D.s == 0:
				D.s = 1
				fake = MRR.fake
				if not fk:
					fk = true
					g.banner("SÓ ACERTE QUANDO O OLHO ESTIVER ABERTO", PINK, 2.4)
			return D.pt > MRR.fake + MRR.real
		"burst":
			if D.s == 0:
				D.s = 1
				b.chg = 0.6
			if D.s == 1 and D.pt > 0.6:
				D.s = 2
				aim(b, 4, 360.0, 0.16, MAG, 10.0)
			return D.pt > 1.2
		"copy":   # copia o padrão da arma do Nick (quantidade, leque e velocidade)
			if D.s == 0:
				D.s = 1
				b.chg = 0.7
				g.sfx("blink")
			if D.s == 1 and D.pt > 0.7:
				D.s = 2
				var n := mini(7, g.player.projectiles)
				var sd := 0.15
				var sp := minf(520.0, 600.0 * 0.62)
				var a := ang_to_player(b)
				for i in n:
					bolt(b.x, b.y, a + (i - (n - 1) / 2.0) * sd, sp, Color("#00f2ff"), 9.0, 4.0 * g.player.area_scale)
				g.banner("ELE USA A SUA ARMA", Color("#00f2ff"), 1.0)
			return D.pt > 1.3
	return true


## Falsa abertura: com o olho fechado e o núcleo brilhando, os tiros voltam.
func on_hit(b: Enemy, p: Projectile, _d: float):
	if fake > 0.0:
		g.fx.burst(p.x, p.y, PINK, 4, 120.0)
		bolt(b.x, b.y, ang_to_player(b) + (randf() - 0.5) * 0.3, 300.0, PINK, 8.0, 5.0)
		g.sfx("tink")
		return 1e-6
	return null


func on_phase(_b: Enemy, ph: int) -> void:
	if ph == 1:
		g.banner("A IMAGEM SE SOLTA", MAG, 2.0)
		flip_t = 4.0
		g.sfx("phase")


# ======================================================================
# desenho (vetorial, drawMirror do HTML)
# ======================================================================
func _ship(R: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(R, 0), Vector2(-R, R * 0.8), Vector2(-R * 0.5, 0), Vector2(-R, -R * 0.8)])


## Desenha a nave espelhada em (x, y). st: {t, al, sc, ph, chg, flash}; mem guarda o rastro (hist, ht).
func draw_mirror(c: CanvasItem, x: float, y: float, st: Dictionary, mem: Dictionary) -> void:
	var P: PlayerState = g.player
	var R := P.radius * 1.9
	var a := atan2(P.y - y, P.x - x)
	var t: float = st.t
	var al: float = st.al
	if not mem.has("hist"):
		mem.hist = []
	var H: Array = mem.hist
	if not mem.has("ht") or t - float(mem.ht) > 0.05:
		mem.ht = t
		H.push_front([x, y, a])
		if H.size() > 6:
			H.pop_back()
	for i in range(1, H.size()):
		var h: Array = H[i]
		c.draw_set_transform(Vector2(h[0], h[1]), h[2], Vector2.ONE)
		Draw.poly(c, _ship(R), Draw.alpha(Color("#00f2ff") if i % 2 else MAG, (0.3 - i * 0.045) * al))
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sc: float = st.sc
	c.draw_set_transform(Vector2(x, y), t * 0.5, Vector2(sc, sc))
	var oc := PackedVector2Array()
	for i in 8:
		var q := i * 0.7854
		oc.append(Vector2(cos(q), sin(q)) * R * 2.2)
	Draw.poly_stroke(c, oc, Draw.alpha(MAG, 0.55 * al), 2.0)
	for i in 8:
		var q := i * 0.7854 + t * 0.3
		var r := R * 2.2 + sin(t * 2.0 + i) * 6.0
		Draw.poly(c, PackedVector2Array([Vector2(cos(q), sin(q)) * r, Vector2(cos(q + 0.12), sin(q + 0.12)) * (r + 9.0), Vector2(cos(q - 0.12), sin(q - 0.12)) * (r + 9.0)]), Draw.alpha(PINK, al))
	c.draw_set_transform(Vector2(x, y), a, Vector2(sc, sc))
	for sl in [[-5.0 - sin(t * 9.0) * 3.0, Color("#00f2ff"), 0.4], [5.0 + sin(t * 7.0) * 3.0, MAG, 0.5]]:
		var pts := _ship(R)
		for k in pts.size():
			pts[k].x += sl[0]
		Draw.poly(c, pts, Draw.alpha(sl[1], sl[2] * al))
	var body := _ship(R)
	if st.flash > 0.0:
		Draw.poly(c, body, Color(1, 1, 1, al))
	else:
		var cols := PackedColorArray()
		for p in body:
			cols.append(Color("#7a0e72").lerp(Color("#ff8cf6"), clampf((p.x + R) / (2.0 * R), 0.0, 1.0)) * Color(1, 1, 1, al))
		c.draw_polygon(body, cols)
	Draw.poly_stroke(c, body, Color(1, 1, 1, al), 1.6)
	Draw.poly(c, PackedVector2Array([Vector2(R * 0.5, 0), Vector2(-R * 0.2, R * 0.3), Vector2(-R * 0.2, -R * 0.3)]), Color(1, 1, 1, 0.55 * al))
	var fl := sin(t * 30.0)
	Draw.poly(c, PackedVector2Array([Vector2(-R * 0.6, 0), Vector2(-R * 1.5 - fl * 6.0, R * 0.25), Vector2(-R * 1.5 - fl * 6.0, -R * 0.25)]), Color(0, 0.95, 1, (0.5 + 0.4 * fl) * al))
	if st.ph > 0:
		for i in 5:
			c.draw_line(Vector2.ZERO, Vector2(cos(i * 1.3 + 1.0), sin(i * 1.3 + 1.0)) * R * 1.6, Color(1, 1, 1, 0.8 * al), 1.0, true)
	if st.chg > 0.0:
		Draw.ring(c, Vector2.ZERO, R + 8.0 + st.chg * 40.0, Color(1, 1, 1, 0.8), 1.0)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	Draw.ellipse(c, Vector2(b.x, b.y + 30.0), 26.0, 8.0, Color(0, 0, 0, 0.4))   # só o verdadeiro tem sombra
	draw_mirror(c, b.x, b.y, {"t": b.t, "al": b.al, "sc": b.sc, "ph": b.ph, "chg": b.chg, "flash": b.flash}, b.d)
	var open := not (fake > 0.0)
	var o := Vector2(b.x, b.y - 2.0)
	Draw.ellipse(c, o, 10.0, 6.0 if open else 1.2, Color.WHITE)
	if open:
		var a := ang_to_player(b)
		Draw.circle(c, o + Vector2(cos(a) * 4.0, sin(a) * 2.0), 3.0, Color.BLACK)
	if real > 0.0:
		Draw.ring(c, Vector2(b.x, b.y), 34.0, Color(1, 0.82, 0.24, 0.9), 3.0)


func draw_add(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0 or fake <= 0.0:
		return
	Draw.radial(c, Vector2(b.x, b.y), 40.0, Color(1, 1, 1, 0.5 + 0.3 * sin(g.game_time * 16.0)), Color(1, 0.24, 0.95, 0.0))


## Reflexos e ecos (drawMirrorExtras).
func draw_top_always(c: CanvasItem) -> void:
	for r in refl:
		var al := 0.55 + 0.25 * sin(g.game_time * 10.0 + r.t)
		draw_mirror(c, r.x, r.y, {"t": g.game_time + r.t, "al": 0.7 * al, "sc": 1.0, "ph": 0, "chg": 0.0, "flash": 0.0}, r)
	for e in ech:
		if e.t < 0.6:
			Draw.dashed_ring(c, Vector2(e.x, e.y), 24.0, 4.0, 4.0, 0.0, Color(1, 0.54, 0.96, e.t / 0.6 * 0.6), 1.0)
		else:
			c.draw_set_transform(Vector2(e.x, e.y), 0.0, Vector2.ONE)
			Draw.poly(c, _ship(g.player.radius), Color(1, 0.54, 0.96, 0.5))
			c.draw_set_transform_matrix(Transform2D.IDENTITY)
