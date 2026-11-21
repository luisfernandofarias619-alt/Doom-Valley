class_name BossIlluminati
extends BossBase
## ILLUMINATTI · Templo do Olho (força 7 · estranheza 6). Sprites das folhas do criador.
## O OLHAR (raio que persegue com atraso), PIRÂMIDES que param e se dividem em três, ENXAME DE OLHOS que
## investem em fila (com linha de aviso), RAIOS nos vértices de um triângulo, INVESTIDA com rastro dourado,
## TELETRANSPORTE para as pirâmides e o JULGAMENTO (setores girando). Na fase 2 os 4 OLHOS DO PISO formam
## um enigma: feche todos (pise neles) e ele fica atordoado; espinhos sobem do chão.

const ILC := {"gap": [1.25, 0.95, 0.75], "sc": 1.05}
const GOLD := Color("#ffd23d")
const CLAMP_ANIMS := ["energia", "dominio", "raio", "hurt", "tele", "quebra", "levitar"]

var deaths: Array[Dictionary] = []
var judge: Enemy = null


func clear_visuals() -> void:
	deaths.clear()


func on_spawn(b: Enemy) -> void:
	b.d = {"cur": "", "s": 0, "pt": 0.0, "lp": "", "trans": 0.0, "pl": [], "ey": [], "ws": []}
	b.an = "move"
	b.fps = 8.0


func ai(b: Enemy, dt: float, ph: int) -> void:
	var D: Dictionary = b.d
	var A = g.arena.cur
	var P: PlayerState = g.player
	b.af += dt * b.fps
	if D.trans > 0.0:   # quebra de fase: racha e se ergue
		D.trans -= dt
		b.vuln = 1.0
		if D.trans < 0.85 and b.an != "levitar":
			b.an = "levitar"
			b.af = 0.0
			b.fps = 6.0
			g.fx.burst(b.x, b.y - 30.0, Color("#fff3a0"), 22, 220.0)
		return
	if b.stun > 0.0:
		b.vuln = 2.0
		if b.an != "stun":
			b.an = "stun"
			b.af = 0.0
		b.fps = 6.0
		return
	b.vuln = 1.0
	if A != null and A.has("eyes") and ph >= 1:
		var opened := 0
		for e in A.eyes:
			if e.open:
				opened += 1
		if opened == 0 and not A.puz:
			A.puz = true
			for e in A.eyes:
				e.open = true
				e.cl = false
			g.banner("OS OLHOS DO PISO SE ABREM · PISE NELES", GOLD, 2.4)
		for e in A.eyes:
			if not e.open:
				continue
			if Vector2(P.x - e.x, P.y - e.y).length() < 34.0:
				e.open = false
				e.cl = true
				g.sfx("key")
				g.fx.burst(e.x, e.y, Color("#3dff7a"), 14, 160.0)
			else:
				e.cd = (e.cd if e.cd > 0.0 else 2.0 + randf() * 2.0) - dt
				if e.cd <= 0.0:
					e.cd = 3.2
					hz({"k": "b", "x": e.x, "y": e.y, "x2": P.x + (P.x - e.x) * 2.0, "y2": P.y + (P.y - e.y) * 2.0, "w": 18.0, "tw": 0.9, "ta": 0.25, "dmg": 9.0, "col": GOLD})
		var any_open := false
		for e in A.eyes:
			if e.open:
				any_open = true
		if A.puz and not any_open:
			A.puz = false
			b.stun = 3.0
			D.cur = ""
			g.hazards.clear()
			g.banner("ENIGMA RESOLVIDO · O OLHO ESTÁ CEGO", Color("#3dff7a"), 2.0)
			g.sfx("victory")
			g.shake(6.0)
			var AA = A
			g.get_tree().create_timer(9.0).timeout.connect(func():
				if g.enc.boss == b:
					for e in AA.eyes:
						e.cl = false)
	if A != null and A.has("spk") and ph >= 1:
		A.spT -= dt
		if A.spT <= 0.0:
			A.spT = 3.5
			var B := box()
			for i in 3:
				A.spk.append({"x": B.position.x + 60.0 + randf() * (B.size.x - 120.0), "y": B.position.y + 60.0 + randf() * (B.size.y - 120.0), "t": 0.0})
	if A != null and A.has("spk"):
		for i in range(A.spk.size() - 1, -1, -1):
			var s: Dictionary = A.spk[i]
			s.t += dt
			if s.t > 1.0 and s.t < 2.2 and absf(P.x - s.x) < 30.0 and absf(P.y - s.y) < 30.0 and not P.is_dashing:
				g.take_damage(14.0, "area")
			if s.t > 2.4:
				A.spk.remove_at(i)
	if D.cur != "":
		D.pt += dt
		if _run(b, dt, ph):
			D.cur = ""
			D.s = 0
			b.an = "move"
			b.fps = 8.0
			b.cd = float(ILC.gap[ph]) / float(g.cfg.bossRate)
	else:
		var a := b.t * 0.35
		var ox := b.x
		bmv(b, dt, P.x + cos(a) * 240.0, P.y - 200.0 + sin(a * 1.3) * 60.0, 0.9)
		b.an = "move" if b.spd > 70.0 else "idle"
		b.fps = 7.0 if b.spd > 70.0 else 6.0
		b.face = -1.0 if b.x < ox else 1.0
		b.cd -= dt
		if b.cd <= 0.0:
			var L: Array
			if ph == 0:
				L = ["gaze", "pyr", "eyes", "bolt"]
			elif ph == 1:
				L = ["gaze", "pyr", "eyes", "bolt", "dash", "tele"]
			else:
				L = ["judge", "gaze", "eyes", "dash", "pyr", "judge"]
			var n: String = L[randi() % L.size()]
			while n == D.lp and L.size() > 1:
				n = L[randi() % L.size()]
			D.lp = n
			D.cur = n
			D.pt = 0.0
			D.s = 0
			if A != null:
				A.glow = 1.0
	if b.vis != 0 and dist_to_player(b) < b.radius * 0.8 + P.radius:
		g.contact(float(b.bd.cd) * float(g.cfg.bossDmg), b)


func _run(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	var P: PlayerState = g.player
	var B := box()
	match String(D.cur):
		"gaze":   # o OLHAR: raio que acompanha o Nick com atraso
			if D.s == 0:
				D.s = 1
				b.an = "energia"
				b.af = 0.0
				b.fps = 4.0
				D.ga = ang_to_player(b)
				g.sfx("phase")
			if D.s == 1 and D.pt > 0.9:
				D.s = 2
				D.gz = hz({"k": "b", "src": b, "ang": D.ga, "om": 0.0, "len": 1400.0, "w": 30.0, "tw": 0.5, "ta": 3.2 + ph * 0.6, "dps": 48.0, "col": GOLD})
			if D.s == 2 and D.has("gz") and not D.gz.is_empty():
				var df := angle_difference(D.gz.ang, ang_to_player(b))
				D.gz.om = clampf(df * 1.4, -0.7 - ph * 0.25, 0.7 + ph * 0.25)   # persegue, mas mais devagar que o Nick consegue correr em volta
			b.an = "energia"
			b.af = minf(1.9, D.pt * 2.2) if D.pt < 0.9 else 2.0
			return D.pt > 1.5 + 3.2 + ph * 0.6
		"pyr":   # pirâmides que param e se dividem
			if D.s == 0:
				D.s = 1
				b.an = "basico"
				b.af = 0.0
				b.fps = 5.0
			if D.s == 1 and D.pt > 0.5:
				D.s = 2
				D.pl = []
				var a := ang_to_player(b)
				var n := 3 + ph
				for i in n:
					var p := bolt(b.x, b.y - 30.0, a + (i - (n - 1) / 2.0) * 0.4, 300.0, GOLD, 10.0, 10.0, {"spr": "tri", "ss": 0.28, "stop": 0.55 + i * 0.05})
					D.pl.append(p)
				g.sfx("bossfire")
			if D.s == 2:
				for p in D.pl:
					if p.stop >= 0.0:
						p.stop -= dt
						if p.stop <= 0.0:
							p.stop = 0.0
							p.vx *= 0.02
							p.vy *= 0.02
							p.split = (p.split if p.split > 0.0 else 0.45) - dt
							if p.split <= 0.0 and not p.sd:
								p.sd = true
								g.enemy_projectiles.erase(p)
								for k in 3:
									bolt(p.x, p.y, atan2(P.y - p.y, P.x - p.x) + k * 2.094, 250.0, GOLD, 8.0, 6.0, {"spr": "tri", "ss": 0.16})
								g.fx.burst(p.x, p.y, GOLD, 6, 140.0)
			return D.pt > 2.2
		"eyes":   # enxame de olhos: orbitam e investem em fila, cada um com linha de aviso
			if D.s == 0:
				D.s = 1
				b.an = "esferas"
				b.af = 0.0
				b.fps = 4.0
				D.ey = []
				var n := 4 + ph
				for i in n:
					D.ey.append({"a": float(i) / n * TAU, "st": 0, "t": 0.0, "x": b.x, "y": b.y})
				g.sfx("mut")
			for i in D.ey.size():
				var e: Dictionary = D.ey[i]
				e.t += dt
				if e.st == 0:
					e.a += dt * 2.0
					e.x = b.x + cos(e.a) * 80.0
					e.y = b.y - 40.0 + sin(e.a) * 50.0
					if D.pt > 1.0 + i * 0.45:
						e.st = 1
						e.t = 0.0
						e.tx = P.x
						e.ty = P.y
						hz({"k": "b", "x": e.x, "y": e.y, "x2": e.x + (e.tx - e.x) * 2.4, "y2": e.y + (e.ty - e.y) * 2.4, "w": 22.0, "tw": 0.55, "ta": 0.01, "dmg": 0.0, "col": GOLD})
				elif e.st == 1 and e.t > 0.55:
					e.st = 2
					bolt(e.x, e.y, atan2(e.ty - e.y, e.tx - e.x), 560.0, GOLD, 12.0, 9.0, {"spr": "olhinho", "ss": 0.75, "pry": true, "src": b})
			return D.pt > 1.4 + D.ey.size() * 0.45
		"bolt":   # raios nos vértices de um triângulo em volta do Nick
			if D.s == 0:
				D.s = 1
				b.an = "raio"
				b.af = 0.0
				b.fps = 3.0
				var a0 := randf() * TAU
				var R := 120.0 + ph * 30.0
				for k in 2 + ph:
					for i in 3:
						var a := a0 + i * 2.094 + k * 1.047
						var r := R * (k + 1) * 0.75
						hz({"k": "c", "x": clampf(P.x + cos(a) * r, B.position.x + 30.0, B.end.x - 30.0), "y": clampf(P.y + sin(a) * r, B.position.y + 30.0, B.end.y - 30.0), "r": 44.0, "tw": 1.0 + k * 0.35, "ta": 0.2, "dmg": 18.0, "col": Color("#fff3a0")})
				g.sfx("phase")
			return D.pt > 2.0
		"dash":   # investida com rastro dourado
			if D.s == 0:
				D.s = 1
				b.an = "passo"
				b.af = 0.0
				b.fps = 8.0
				D.da = ang_to_player(b)
				hz({"k": "b", "x": b.x, "y": b.y, "x2": b.x + cos(D.da) * 1300.0, "y2": b.y + sin(D.da) * 1300.0, "w": 70.0, "tw": 0.8, "ta": 0.02, "dmg": 0.0, "col": GOLD})
				b.face = -1.0 if cos(D.da) < 0.0 else 1.0
			if D.s == 1 and D.pt > 0.8:
				D.s = 2
				b.chg2 = true
			if D.s == 2:
				var v := 900.0
				b.x += cos(D.da) * v * dt
				b.y += sin(D.da) * v * dt
				b.af = 3.0 + int(D.pt * 10.0) % 3
				if randf() < dt * 30.0:
					hz({"k": "c", "x": b.x, "y": b.y, "r": 30.0, "tw": 0.1, "ta": 1.1, "dps": 30.0, "col": GOLD})
				if dist_to_player(b) < b.radius + P.radius:
					g.contact(30.0 * float(g.cfg.bossDmg), b)
				if b.x < B.position.x + 50.0 or b.x > B.end.x - 50.0 or b.y < B.position.y + 50.0 or b.y > B.end.y - 50.0 or D.pt > 2.3:
					b.x = clampf(b.x, B.position.x + 50.0, B.end.x - 50.0)
					b.y = clampf(b.y, B.position.y + 50.0, B.end.y - 50.0)
					D.s = 3
					b.chg2 = false
					g.shake(4.0)
					g.sfx("rhslam")
			return D.s == 3 and D.pt > 2.6
		"tele":   # teletransporte para perto de uma pirâmide (ou do centro)
			if D.s == 0:
				D.s = 1
				b.an = "tele"
				b.af = 0.0
				b.fps = 4.0
				b.inv = 1.0
				var A = g.arena.cur
				var Pyr: Array = []
				if A != null:
					for o in A.obj:
						if o.k == "piramide" and not o.get("dead", false):
							Pyr.append(o)
				var q := {"x": A.w / 2.0 if A != null else g.vw / 2.0, "y": A.h * 0.35 if A != null else g.vh / 2.0}
				if not Pyr.is_empty():
					q = Pyr[randi() % Pyr.size()]
				D.tx = q.x
				D.ty = q.y + 90.0
				hz({"k": "c", "x": D.tx, "y": D.ty, "r": 60.0, "tw": 0.8, "ta": 0.15, "dmg": 14.0, "col": GOLD})
			if D.s == 1 and D.pt > 0.4:
				b.vis = 0
			if D.s == 1 and D.pt > 0.8:
				D.s = 2
				b.vis = 1
				b.x = D.tx
				b.y = D.ty
				b.af = 2.0
				ring(b, 10, 230.0, GOLD, 0.0, 9.0)
				g.fx.burst(b.x, b.y, GOLD, 24, 260.0)
			return D.pt > 1.3
		"judge":   # JULGAMENTO: o emblema acende; três setores girando + colunas de luz
			var A = g.arena.cur
			if D.s == 0:
				D.s = 1
				b.an = "dominio"
				b.af = 0.0
				b.fps = 2.0
				g.banner("JULGAMENTO", GOLD, 2.0)
				g.sfx("rhroar")
				g.shake(5.0)
				b.inv = 0.6
				D.jx = A.w / 2.0 if A != null else g.vw / 2.0
				D.jy = A.h * 0.55 if A != null else g.vh / 2.0
				D.ja = randf() * TAU
				for i in 3:
					hz({"k": "w", "x": D.jx, "y": D.jy, "r": 900.0, "ang": D.ja + i * 2.094, "half": 0.42, "tw": 1.4, "ta": 0.01, "dmg": 0.0, "col": GOLD})
			if D.s == 1 and D.pt > 1.4:
				D.s = 2
				D.ws = [D.ja, D.ja + 2.094, D.ja + 4.188]
				judge = b
			if D.s == 2:
				for i in 3:
					D.ws[i] += dt * 0.55
					var a := atan2(P.y - D.jy, P.x - D.jx)
					if absf(angle_difference(D.ws[i], a)) < 0.42 and Vector2(P.x - D.jx, P.y - D.jy).length() > 40.0 and not P.is_dashing:
						g.take_damage(26.0 * dt, "area")
				if randf() < dt * 3.0:
					hz({"k": "c", "x": B.position.x + 80.0 + randf() * (B.size.x - 160.0), "y": B.position.y + 80.0 + randf() * (B.size.y - 160.0), "r": 40.0, "tw": 0.8, "ta": 0.4, "dmg": 15.0, "col": Color("#fff3a0")})
			if D.pt > 1.4 + 4.2:
				judge = null
				return true
			return false
	return true


func on_phase(b: Enemy, ph: int) -> void:
	b.d.cur = ""
	g.hazards.clear()
	b.stun = 0.0
	b.an = "quebra"
	b.af = 0.0
	b.fps = 5.0
	b.d.trans = 1.7
	b.inv = 1.8
	judge = null
	g.shake(8.0)
	g.hitstop(0.15)
	g.sfx("rhroar")
	for i in 3:
		g.fx.ripple(b.x, b.y, 20.0, 200.0 + i * 100.0, GOLD, 0.9, 0.7 + i * 0.2)
	g.banner("O OLHO SE ABRE" if ph == 1 else "FORMA DIVINA", GOLD, 2.2)


func on_dead(b: Enemy) -> void:
	judge = null
	var fr: Array = []
	for a in ["morte", "destroi", "desfaz"]:
		for i in Assets.anim_len("ilu", a):
			fr.append([a, i])
	if not fr.is_empty():
		deaths.append({"fr": fr, "x": b.x, "y": b.y, "t": 0.0})


func update_always(dt: float) -> void:
	for i in range(deaths.size() - 1, -1, -1):
		var d: Dictionary = deaths[i]
		d.t += dt
		if d.t > d.fr.size() / 7.0 + 0.6:
			deaths.remove_at(i)


# ======================================================================
# desenho
# ======================================================================
func _fi(b: Enemy) -> int:
	var an := b.an if b.an != "" else "move"
	var fi := floori(b.af)
	if an in CLAMP_ANIMS:
		fi = mini(maxi(0, Assets.anim_len("ilu", an) - 1), fi)
	return fi


func draw(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	Draw.ellipse(c, Vector2(b.x, b.y + 40.0), 40.0, 10.0, Color(0, 0, 0, 0.3))
	if b.vuln > 1.0:
		Draw.ellipse_ring(c, Vector2(b.x, b.y + 40.0), 52.0, 12.0, Color(0.24, 1, 0.48, 0.75 + 0.25 * sin(b.t * 12.0)), 3.0)
		Draw.text(c, Assets.font_mono_bold, "ATORDOADO", Vector2(b.x, b.y - 110.0), 12, Color("#3dff7a"), HORIZONTAL_ALIGNMENT_CENTER)


func draw_sprites(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var fl := sin(b.t * 2.0) * 5.0
	var an := b.an if b.an != "" else "move"
	Assets.draw_atl(c, "ilu", an, _fi(b), b.x, b.y + 44.0 + fl, ILC.sc * b.sc, (b.face * -1.0) if an == "passo" else 1.0, b.al)
	for e in b.d.get("ey", []):
		if e.st == 0:
			Assets.draw_atl(c, "ilu", "olhinho", 0, e.x, e.y, 0.75, 1.0)


func draw_add(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0 or b.flash <= 0.0:
		return
	var fl := sin(b.t * 2.0) * 5.0
	Assets.draw_atl(c, "ilu", b.an if b.an != "" else "move", _fi(b), b.x, b.y + 44.0 + fl, ILC.sc, 1.0, b.flash * 0.5)


## Setores do Julgamento (aditivo) e quadros de morte (o 'desfaz' também aditivo).
func draw_add_always(c: CanvasItem) -> void:
	var b := judge
	if b != null and b.d.get("cur", "") == "judge" and b.d.s == 2:
		var o := Vector2(b.d.jx, b.d.jy)
		for a in b.d.ws:
			Draw.sector(c, o, 950.0, a - 0.42, a + 0.42, Color(1, 0.82, 0.24, 0.32))
			Draw.arc(c, o, 950.0, a - 0.42, a + 0.42, Color(1, 0.95, 0.63, 0.7), 3.0)
			c.draw_line(o, o + Vector2(cos(a - 0.42), sin(a - 0.42)) * 950.0, Color(1, 0.95, 0.63, 0.7), 3.0)
			c.draw_line(o, o + Vector2(cos(a + 0.42), sin(a + 0.42)) * 950.0, Color(1, 0.95, 0.63, 0.7), 3.0)
	for d in deaths:
		var n: int = d.fr.size()
		var k := floori(d.t * 7.0)
		var f: Array = d.fr[mini(n - 1, k)]
		if f[0] == "desfaz":
			Assets.draw_atl(c, "ilu", f[0], f[1], d.x, d.y + 44.0, ILC.sc, 1.0, _death_alpha(d))


func draw_sprites_always(c: CanvasItem) -> void:
	for d in deaths:
		var n: int = d.fr.size()
		var k := floori(d.t * 7.0)
		var f: Array = d.fr[mini(n - 1, k)]
		if f[0] != "desfaz":
			Assets.draw_atl(c, "ilu", f[0], f[1], d.x, d.y + 44.0, ILC.sc, 1.0, _death_alpha(d))


func _death_alpha(d: Dictionary) -> float:
	var n: int = d.fr.size()
	var last: bool = floori(d.t * 7.0) >= n
	return maxf(0.0, 1.0 - (d.t - n / 7.0) / 0.6) if last else 1.0
