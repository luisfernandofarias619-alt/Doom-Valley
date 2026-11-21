class_name BossVesperon
extends BossBase
## VESPERON, O SEMEADOR DE CINZAS · Rotunda dos Manuscritos (força 7 · estranheza 4).
## Duelo de leitura: ele também tem estamina, rola para fugir dos tiros e entra em GUARDA (círculo de runas)
## que devolve os tiros como brasas. Aparar a foice no tempo certo faz ele cambalear e perder estamina.
## Sem estamina fica EXAUSTO (ajoelhado, dano ×2).
## Fase 1: Páginas Cortantes (aparáveis), Círculos de Anotação (colunas de fogo), Passo Espectral.
## 50%: a máscara racha. Fase 2: combos de 4 golpes que encurtam a estamina do Nick, Tempestade de Cinderfall
## (abrigue-se nas runas), O Verso Final (pelas costas ele fica exposto) e brasas nas fendas do mármore.

const VSP := {"rg": 20.0, "dodge": {"cost": 24.0, "dist": 160.0, "dur": 0.32, "cd": 1.0}, "guard": {"dur": 1.35, "cost": 6.0, "refl": 4.0},
	"foice": {"cost": 18.0, "tw": 0.42, "ta": 0.12}, "pages": {"cost": 12.0}, "runas": {"cost": 14.0}, "passo": {"cost": 22.0}, "exh": 2.6, "gap": [1.15, 0.8], "scale": 1.0}
const ORANGE := Color("#ff9a3d")

var smoke := 0.0
var deaths: Array[Dictionary] = []


func _init(game) -> void:
	super(game)
	Events.player_damaged.connect(_on_player_damaged)


func clear_visuals() -> void:
	deaths.clear()
	smoke = 0.0


func on_spawn(b: Enemy) -> void:
	b.d = {"cur": "", "s": 0, "pt": 0.0, "st": "move", "stT": 0.0, "dcd": 1.0, "gcd": 3.0, "rec": 0.0, "lp": "", "stg0": 0, "bk": false}
	b.stm = 100.0
	b.an = "idle"
	b.af = 0.0
	b.cd = 1.6


func _S(b: Enemy, st: String, an: String = "") -> void:
	b.d.st = st
	b.d.stT = 0.0
	if an != "":
		b.an = an
		b.af = 0.0


func ai(b: Enemy, dt: float, ph: int) -> void:
	var D: Dictionary = b.d
	var P: PlayerState = g.player
	D.stT += dt
	b.af += dt * b.fps
	b.face = -1.0 if P.x < b.x else 1.0
	if b.stg > D.stg0:   # o Nick aparou: ele cambaleia
		D.stg0 = b.stg
		D.cur = ""
		g.hazards.clear()
		b.stm = maxf(0.0, b.stm - 30.0)
		_S(b, "stagger", "hurt")
		b.fps = 6.0
		g.sfx("pfail")
		g.fx.burst(b.x, b.y - 40.0, Color("#ffe08a"), 14, 220.0)
	match String(D.st):
		"trans":
			b.inv = 0.2
			b.vuln = 1.0
			if D.stT > 2.6:
				_S(b, "move", "idle")
				b.cd = 0.6
			else:
				var k: float = 1.0 - D.stT / 2.6
				P.x += (b.x - P.x) * dt * 0.35 * k
				P.y += (b.y - P.y) * dt * 0.35 * k
				if randf() < dt * 40.0:
					g.fx.burst(b.x + (randf() - 0.5) * 300.0, b.y + (randf() - 0.5) * 300.0, Color("#3a3430") if randf() < 0.5 else ORANGE, 2, 60.0)
			return
		"exh":
			b.vuln = 2.0
			b.an = "death"
			b.af = minf(3.9, D.stT * 3.0)
			if D.stT > VSP.exh:
				b.stm = 60.0
				_S(b, "move", "idle")
				g.banner("VESPERON SE LEVANTA", ORANGE, 1.0)
			return
		"stagger":
			b.vuln = 1.5
			if D.stT > 1.1:
				_S(b, "move", "idle")
				b.cd = 0.5
			return
	if b.stm <= 0.0 and D.st != "dodge":
		_S(b, "exh", "death")
		D.cur = ""
		g.hazards.clear()
		g.sfx("exhaust")
		g.banner("VESPERON ESTÁ EXAUSTO", Color("#ffe08a"), 1.6)
		g.fx.burst(b.x, b.y - 50.0, Color("#ffe08a"), 16, 200.0)
		return
	b.vuln = 1.0
	D.dcd -= dt
	D.gcd -= dt
	if D.st == "dodge":
		b.inv = 0.05
		var k: float = D.stT / VSP.dodge.dur
		var v: float = VSP.dodge.dist / VSP.dodge.dur * 1.5 * (1.0 - k)
		b.x += D.dx * v * dt
		b.y += D.dy * v * dt
		var B := box()
		b.x = clampf(b.x, B.position.x + 40.0, B.end.x - 40.0)
		b.y = clampf(b.y, B.position.y + 40.0, B.end.y - 40.0)
		if k >= 1.0:
			_S(b, "move", "idle")
			D.rec = 0.3
		return
	if D.st == "guard":
		b.an = "def"
		b.af = minf(2.9, D.stT * 6.0)
		b.stm -= VSP.guard.cost * dt
		if D.stT > VSP.guard.dur:
			_S(b, "move", "idle")
			D.gcd = 5.0
			b.cd = 0.4
		return
	if D.rec > 0.0:
		D.rec -= dt
		return
	if D.cur != "":
		D.pt += dt
		if _run(b, dt, ph):
			D.cur = ""
			D.s = 0
			_S(b, "move", "idle")
			b.cd = float(VSP.gap[1 if ph else 0]) / float(g.cfg.bossRate)
		return
	b.stm = minf(100.0, b.stm + VSP.rg * dt)
	# rolamento do chefe: lê os tiros que vêm na direção dele
	if D.dcd <= 0.0 and b.stm >= VSP.dodge.cost:
		var th := 0
		for p in g.projectiles:
			var dx: float = b.x - p.x
			var dy: float = b.y - p.y
			var dd := sqrt(dx * dx + dy * dy)
			if dd < 190.0 and (p.vx * dx + p.vy * dy) / (Vector2(p.vx, p.vy).length() * dd + 1e-6) > 0.93:
				th += 1
		if th >= (1 if ph else 2):
			var a := ang_to_player(b) + (1.0 if randf() < 0.5 else -1.0) * PI / 2.0
			D.dx = cos(a)
			D.dy = sin(a)
			b.stm -= VSP.dodge.cost
			D.dcd = VSP.dodge.cd * (0.8 if ph else 1.0)
			_S(b, "dodge", "dash")
			b.fps = 12.0
			g.sfx("roll")
			g.fx.burst(b.x, b.y - 30.0, Color("#3a3430"), 12, 160.0)
			return
	# guarda: quando o Nick insiste nos tiros
	if D.gcd <= 0.0 and b.stm >= 30.0:
		var n := 0
		for p in g.projectiles:
			if Vector2(p.x - b.x, p.y - b.y).length() < 420.0:
				n += 1
		if n >= 4:
			_S(b, "guard", "def")
			b.fps = 8.0
			g.sfx("phase")
			return
	var ideal := 190.0 if ph else 250.0
	var a := ang_to_player(b)
	var sa := a + PI / 2.0 * (1.0 if sin(b.t * 0.7) > 0.0 else -1.0)
	var tx := P.x - cos(a) * ideal + cos(sa) * 60.0
	var ty := P.y - sin(a) * ideal + sin(sa) * 60.0
	var ox := b.x
	var oy := b.y
	bmv(b, dt, tx, ty, 1.4 if ph else 1.1)
	b.an = "walk" if Vector2(b.x - ox, b.y - oy).length() > 40.0 * dt else "idle"
	b.fps = 9.0
	b.cd -= dt
	if b.cd <= 0.0:
		var L := ["foice", "storm", "verso", "pages", "foice", "passo"] if ph else ["pages", "runas", "foice", "passo", "pages"]
		var n: String = L[randi() % L.size()]
		while n == D.lp and L.size() > 1:
			n = L[randi() % L.size()]
		var cost: float = VSP.foice.cost if n == "foice" else (VSP.passo.cost if n == "passo" else (VSP.runas.cost if n == "runas" else VSP.pages.cost))
		if b.stm >= cost:
			b.stm -= cost
			D.lp = n
			D.cur = n
			D.pt = 0.0
			D.s = 0
		else:
			b.cd = 0.5
	if dist_to_player(b) < b.radius * 0.8 + P.radius:
		g.contact(float(b.bd.cd) * float(g.cfg.bossDmg), b)


func _run(b: Enemy, dt: float, ph: int) -> bool:
	var D: Dictionary = b.d
	var P: PlayerState = g.player
	var B := box()
	match String(D.cur):
		"pages":   # Páginas Cortantes: rajadas em leque; aparáveis e param nos pilares
			if D.s == 0:
				D.s = 1
				b.an = "tomo"
				b.af = 0.0
				b.fps = 10.0
				b.chg = 0.5
			var n := 3 if ph else 2
			for v in n:
				if D.s == v + 1 and D.pt > 0.5 + v * 0.38:
					D.s += 1
					var a := ang_to_player(b)
					var k := 6 if ph else 5
					for i in k:
						bolt(b.x + b.face * 20.0, b.y - 50.0, a + (i - (k - 1) / 2.0) * 0.17, 360.0 if ph else 300.0, Color("#e8dcc0"), 9.0, 6.0, {"shard": true, "pry": true, "src": b})
					g.sfx("swish")
			return D.pt > 0.6 + n * 0.38
		"runas":   # Círculos de Anotação: runas no chão viram colunas de fogo
			if D.s == 0:
				D.s = 1
				b.an = "tomo"
				b.af = 0.0
				b.fps = 8.0
				var n := 3 + ph
				for i in n:
					var a := float(i) / n * TAU + b.t
					var r := 110.0 if i else 0.0
					hz({"k": "c", "x": clampf(P.x + cos(a) * r, B.position.x + 40.0, B.end.x - 40.0), "y": clampf(P.y + sin(a) * r, B.position.y + 40.0, B.end.y - 40.0), "r": 52.0, "tw": 1.25, "ta": 0.5, "dmg": 20.0, "col": ORANGE, "rune": true})
				g.sfx("phase")
			return D.pt > 1.9
		"foice":   # combo da foice: aproxima, prepara e corta (cada corte é aparável)
			var n := 4 if ph else 3
			var tw: float = VSP.foice.tw * (0.8 if ph else 1.0)
			var per := tw + 0.26
			if D.s == 0:
				D.s = 1
				b.an = "walk"
				b.fps = 12.0
			if D.s == 1:
				if dist_to_player(b) > 120.0 and D.pt < 1.2:
					var a := ang_to_player(b)
					b.x += cos(a) * 420.0 * dt
					b.y += sin(a) * 420.0 * dt
					return false
				D.s = 2
				D.p0 = D.pt
			var k: float = D.pt - D.p0
			var i := floori(k / per)
			if i >= n:
				return k > n * per + 0.3
			if D.s == 2 + i:
				D.s = 3 + i
				var a := ang_to_player(b)
				var om := -1.0 if i % 2 else 1.0
				b.an = "foice"
				b.af = 0.0
				b.fps = 6.0 / per
				hz({"k": "b", "x": b.x, "y": b.y - 20.0, "x2": b.x + cos(a) * 190.0, "y2": b.y - 20.0 + sin(a) * 190.0, "ang": a, "om": om, "w": 84.0, "tw": tw, "ta": VSP.foice.ta, "dmg": 16.0 if ph else 14.0, "col": ORANGE, "slash": true, "ml": true, "bsrc": b, "vsp": ph > 0})
				g.sfx("rhswipe")
			return false
		"passo":   # Passo Espectral: some na fumaça e aparece pelas costas
			if D.s == 0:
				D.s = 1
				b.an = "dash"
				b.af = 0.0
				b.fps = 8.0
				b.inv = 0.9
				g.fx.burst(b.x, b.y - 30.0, Color("#2a2420"), 26, 200.0)
				D.tx = clampf(P.x - cos(P.angle) * 120.0, B.position.x + 40.0, B.end.x - 40.0)
				D.ty = clampf(P.y - sin(P.angle) * 120.0, B.position.y + 40.0, B.end.y - 40.0)
				hz({"k": "c", "x": D.tx, "y": D.ty, "r": 40.0, "tw": 0.7, "ta": 0.02, "dmg": 0.0, "col": Color("#9a8a7a")})
			if D.s == 1 and D.pt > 0.7:
				D.s = 2
				b.x = D.tx
				b.y = D.ty
				b.an = "foice"
				b.af = 0.0
				b.fps = 10.0
				g.fx.burst(b.x, b.y - 30.0, Color("#2a2420"), 30, 240.0)
				var a := ang_to_player(b)
				hz({"k": "b", "x": b.x, "y": b.y - 20.0, "x2": b.x + cos(a) * 170.0, "y2": b.y - 20.0 + sin(a) * 170.0, "ang": a, "om": 1.0, "w": 80.0, "tw": 0.38, "ta": 0.12, "dmg": 18.0, "col": ORANGE, "slash": true, "ml": true, "bsrc": b})
				if Settings.s.amb:
					smoke = 1.2
			return D.pt > 1.5
		"storm":   # Tempestade de Cinderfall: o teto desaba; só as runas protegem
			if D.s == 0:
				D.s = 1
				b.an = "tomo"
				b.af = 0.0
				b.fps = 6.0
				g.banner("TEMPESTADE DE CINDERFALL · ABRIGUE-SE NAS RUNAS", ORANGE, 2.2)
				g.sfx("rhroar")
				g.shake(5.0)
				D.safe = []
				for i in 3:
					D.safe.append({"x": B.position.x + 120.0 + randf() * (B.size.x - 240.0), "y": B.position.y + 120.0 + randf() * (B.size.y - 240.0), "r": 70.0})
				D.safe.append({"x": clampf(P.x + (randf() - 0.5) * 300.0, B.position.x + 90.0, B.end.x - 90.0), "y": clampf(P.y + (randf() - 0.5) * 300.0, B.position.y + 90.0, B.end.y - 90.0), "r": 70.0})
			if D.s < 7 and D.pt > 0.5 + D.s * 0.32:
				D.s += 1
				for k in 7:
					var x := 0.0
					var y := 0.0
					var tr := 0
					while true:
						x = B.position.x + 30.0 + randf() * (B.size.x - 60.0)
						y = B.position.y + 30.0 + randf() * (B.size.y - 60.0)
						var bad := false
						for s in D.safe:
							if Vector2(s.x - x, s.y - y).length() < s.r + 46.0:
								bad = true
						tr += 1
						if not bad or tr >= 20:
							break
					hz({"k": "c", "x": x, "y": y, "r": 46.0, "tw": 1.3, "ta": 0.18, "dmg": 17.0, "col": Color("#c9b28a")})
				var A = g.arena.cur
				if A != null:
					for o in A.obj.duplicate():
						if o.get("brk", false) and randf() < 0.12:
							g.arena.obj_hit(o, 90.0)
			return D.pt > 3.4
		"verso":   # O Verso Final: raio frontal canalizado; pelas costas ele fica exposto
			if D.s == 0:
				D.s = 1
				b.an = "tomo"
				b.af = 0.0
				b.fps = 5.0
				D.va = ang_to_player(b)
				g.banner("O VERSO FINAL", ORANGE, 1.6)
				g.sfx("phase")
				hz({"k": "b", "x": b.x, "y": b.y - 40.0, "x2": b.x + cos(D.va) * 1500.0, "y2": b.y - 40.0 + sin(D.va) * 1500.0, "w": 150.0, "tw": 1.5, "ta": 1.6, "dps": 70.0, "col": ORANGE})
			var back := cos(ang_to_player(b) - D.va) < -0.2
			b.vuln = 2.0 if back else 1.0
			b.face = -1.0 if cos(D.va) < 0.0 else 1.0
			if back and not D.bk:
				D.bk = true
				g.hud_msg("Pelas costas: ele está exposto!", Color("#ffe08a"))
			if D.pt > 1.5 and D.pt < 3.1 and randf() < dt * 20.0:
				var A = g.arena.cur
				if A != null:
					for o in A.obj.duplicate():
						if not o.get("brk", false) or o.get("dead", false):
							continue
						if Hazards.seg_d(o.x, o.y, b.x, b.y, b.x + cos(D.va) * 1500.0, b.y + sin(D.va) * 1500.0) < 90.0:
							g.arena.obj_hit(o, 40.0)
			if D.pt > 3.1:
				if D.bk:
					D.bk = false
					_S(b, "stagger", "hurt")
					D.stT = -0.4
					b.stm = maxf(0.0, b.stm - 25.0)
				return true
			return false
	return true


## Guarda devolve os tiros como brasas; durante o rolamento ele não sofre dano.
func on_hit(b: Enemy, p: Projectile, _d: float):
	if b.d.st == "dodge":
		return 1e-6
	if b.d.st == "guard":
		b.stm -= VSP.guard.refl
		var a := ang_to_player(b) + (randf() - 0.5) * 0.25
		bolt(b.x, b.y - 40.0, a, 380.0, ORANGE, 9.0, 5.0, {"pry": true, "src": b})
		g.fx.burst(p.x, p.y, Color("#ffe08a"), 6, 160.0)
		g.sfx("tink")
		return 1e-6
	return null


func on_phase(b: Enemy, ph: int) -> void:
	if ph == 1:
		_S(b, "trans", "hurt")
		b.fps = 4.0
		b.d.cur = ""
		g.hazards.clear()
		g.banner("A MÁSCARA RACHA", ORANGE, 2.6)
		g.sfx("rhroar")
		g.shake(9.0)
		g.hitstop(0.2)
		for i in 3:
			g.fx.ripple(b.x, b.y, 20.0, 260.0 + i * 120.0, Color("#3a3430") if i else ORANGE, 0.9, 0.8 + i * 0.3)
		var A = g.arena.cur
		if A != null:
			A.p2 = true
			A.embT = 0.0
		b.stm = 100.0


## Golpes da fase 2 encurtam a estamina máxima do Nick por alguns segundos.
func _on_player_damaged(_a: float) -> void:
	var b: Enemy = g.enc.boss
	if b != null and b.ai == self and b.ph >= 1 and b.d.get("cur", "") == "foice":
		g.st_cut = minf(60.0, g.st_cut + 15.0)
		g.st_cut_t = 6.0
		g.player.st = minf(g.player.st, g.st_max_eff())
		g.hud_msg("Estamina máxima reduzida", ORANGE)


func on_dead(b: Enemy) -> void:
	deaths.append({"x": b.x, "y": b.y, "t": 0.0, "face": b.face})


func update_always(dt: float) -> void:
	if smoke > 0.0:
		smoke -= dt
	for i in range(deaths.size() - 1, -1, -1):
		deaths[i].t += dt
		var n := Assets.anim_len("vesp", "death")
		if deaths[i].t > n / 6.0 + 0.6:
			deaths.remove_at(i)


# ======================================================================
# desenho
# ======================================================================
func _frame_index(b: Enemy) -> int:
	var an := b.an if b.an != "" else "idle"
	var n := Assets.anim_len("vesp", an)
	var fi := floori(b.af)
	if an == "death" or an == "def":
		fi = mini(maxi(0, n - 1), fi)
	return fi


func draw(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var t := b.t
	Draw.ellipse(c, Vector2(b.x, b.y + 24.0), 30.0, 8.0, Color(0, 0, 0, 0.35))
	if b.vuln > 1.0 or b.d.st == "exh":
		Draw.ellipse_ring(c, Vector2(b.x, b.y + 24.0), 40.0, 10.0, Color("#fff0a0") if b.d.st == "exh" else Color("#ffd27a"), 3.0)   # anel dourado: hora de bater


func draw_sprites(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var fl := sin(b.t * 2.2) * 4.0
	var sc: float = VSP.scale * b.sc
	var y := b.y + 18.0 + fl
	var an := b.an if b.an != "" else "idle"
	if not Assets.draw_atl(c, "vesp", an, _frame_index(b), b.x, y, sc, b.face, b.al):
		c.draw_rect(Rect2(b.x - 22, b.y - 90, 44, 100), Color("#2a2420"))
		c.draw_rect(Rect2(b.x - 9, b.y - 104, 18, 20), Color("#e8e0d0"))
		c.draw_rect(Rect2(b.x - 1, b.y - 100, 2, 12), ORANGE)


func draw_add(c: CanvasItem, b: Enemy) -> void:
	if b.vis == 0:
		return
	var fl := sin(b.t * 2.2) * 4.0
	var y := b.y + 18.0 + fl
	var an := b.an if b.an != "" else "idle"
	if b.flash > 0.0:
		Assets.draw_atl(c, "vesp", an, _frame_index(b), b.x, y, VSP.scale * b.sc, b.face, b.flash * 0.6)
	if b.d.st == "guard":
		var t := b.t
		Draw.ring(c, Vector2(b.x, b.y - 50.0), 72.0, Color(1, 0.88, 0.54, 0.55 + 0.25 * sin(t * 12.0)), 3.0)
		Draw.dashed_ring(c, Vector2(b.x, b.y - 50.0), 84.0, 6.0, 8.0, t * 40.0, Color(1, 0.88, 0.54, 0.55 + 0.25 * sin(t * 12.0)), 3.0)
	var A = g.arena.cur
	if A != null and A.get("p2", false):   # máscara rachada: a fenda brilha
		c.draw_rect(Rect2(b.x + b.face * 2.0 - 1.0, b.y - 118.0 + fl, 2, 16), Color(1, 0.6, 0.24, 0.6))


func draw_top(c: CanvasItem, b: Enemy) -> void:
	var D: Dictionary = b.d
	if D.get("cur", "") == "storm" and D.has("safe"):
		for s in D.safe:
			var o := Vector2(s.x, s.y)
			Draw.circle(c, o, s.r, Color(1, 0.88, 0.54, 0.25 + 0.15 * sin(g.game_time * 5.0)))
			Draw.dashed_ring(c, o, s.r, 8.0, 6.0, 0.0, Color(1, 0.88, 0.54, 0.9), 2.0)


## Quadros de morte onde ele caiu.
func draw_sprites_always(c: CanvasItem) -> void:
	for d in deaths:
		var n := Assets.anim_len("vesp", "death")
		var k := floori(d.t * 6.0)
		var last := k >= n
		var al := maxf(0.0, 1.0 - (d.t - n / 6.0) / 0.6) if last else 1.0
		Assets.draw_atl(c, "vesp", "death", mini(n - 1, k), d.x, d.y + 18.0, VSP.scale, d.face, al)


## Fumaça do Passo Espectral (vinheta escura na tela).
func draw_screen(c: CanvasItem) -> void:
	var A = g.arena.cur
	if smoke <= 0.0 or A == null or A.id != "rotunda":
		return
	var vw: float = g.vw
	var vh: float = g.vh
	var a := minf(0.55, smoke * 0.5)
	var ctr := Vector2(vw / 2.0, vh / 2.0)
	var r_in := minf(vw, vh) * 0.15
	var r_out := maxf(vw, vh) * 0.7
	var n := 40
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in n:
		var ang := float(i) / n * TAU
		var dir := Vector2(cos(ang), sin(ang))
		pts.append(ctr + dir * r_in)
		cols.append(Color(0.16, 0.14, 0.13, 0.0))
		pts.append(ctr + dir * r_out)
		cols.append(Color(0.16, 0.14, 0.13, a))
	for i in n:
		var a0 := i * 2
		var b0 := ((i + 1) % n) * 2
		idx.append_array([a0, a0 + 1, b0 + 1, a0, b0 + 1, b0])
	RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), idx, pts, cols)
